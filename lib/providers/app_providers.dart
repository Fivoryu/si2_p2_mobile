import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../core/dio_client.dart';
import '../data/api/auth_api.dart';
import '../data/api/ia_api.dart';
import '../data/api/incidente_api.dart';
import '../data/api/taller_api.dart';
import '../data/api/usuario_api.dart';
import '../data/api/vehiculo_api.dart';
import '../data/models/asignacion.dart';
import '../data/models/auth_session.dart';
import '../data/models/incidente.dart';
import '../data/models/usuario.dart';
import '../data/models/vehiculo.dart';
import '../data/local_db.dart';
import '../services/auth_service.dart';
import '../services/in_app_notification_service.dart';
import '../services/push_service.dart';
import '../services/sync_service.dart';

final dioProvider = Provider((ref) => buildDio());

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(dio: ref.watch(dioProvider));
});

final authApiProvider = Provider((ref) => AuthApi(ref.watch(dioProvider)));

final incidenteApiProvider =
    Provider((ref) => IncidenteApi(ref.watch(dioProvider)));

final tallerApiProvider =
    Provider((ref) => TallerApi(ref.watch(dioProvider)));

final iaApiProvider = Provider((ref) => IaApi(ref.watch(dioProvider)));

final vehiculoApiProvider =
    Provider((ref) => VehiculoApi(ref.watch(dioProvider)));

final usuarioApiProvider =
    Provider((ref) => UsuarioApi(ref.watch(dioProvider)));

final authStateProvider = FutureProvider<bool>((ref) async {
  return ref.watch(authServiceProvider).isLoggedIn();
});

class LoginNotifier extends Notifier<AsyncValue<AuthSession?>> {
  @override
  AsyncValue<AuthSession?> build() => const AsyncData(null);

  String? _tenantForEmail(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized == Config.demoEmail.toLowerCase()) {
      return Config.demoTenantId;
    }
    if (normalized.endsWith('@auxilionorte.com')) {
      return Config.demoTenantId;
    }
    return null;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await ref.read(authServiceProvider).login(
            email: email,
            password: password,
            tenantId: _tenantForEmail(email),
          );
      ref.invalidate(authStateProvider);
      ref.invalidate(profileProvider);
      ref.invalidate(vehiculosProvider);
      final dio = ref.read(dioProvider);
      await PushService.init(dio);
      InAppNotificationService.start(dio);
      return session;
    });
  }
}

final loginProvider =
    NotifierProvider<LoginNotifier, AsyncValue<AuthSession?>>(
  LoginNotifier.new,
);

final profileProvider = FutureProvider<Usuario?>((ref) async {
  if (!await ref.watch(authServiceProvider).isLoggedIn()) return null;
  return ref.watch(usuarioApiProvider).me();
});

final vehiculosProvider = FutureProvider<List<Vehiculo>>((ref) async {
  if (!await ref.watch(authServiceProvider).isLoggedIn()) return [];
  if (!await SyncService.hasConnectivity()) {
    final cached = await LocalDb.vehiculosCached();
    if (cached.isNotEmpty) return cached;
    throw Exception('Sin conexión y sin vehículos en caché');
  }
  try {
    final list = await ref.watch(vehiculoApiProvider).list();
    await LocalDb.cacheVehiculos(list);
    return list;
  } catch (_) {
    final cached = await LocalDb.vehiculosCached();
    if (cached.isNotEmpty) return cached;
    rethrow;
  }
});

DateTime _incidenteSortKey(Incidente item) {
  final raw = item.reportadoAt;
  if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
  return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

/// Combina SQLite offline con `/incidentes` sin perder registros ya sincronizados.
List<Incidente> mergeIncidentes(List<Incidente> local, List<Incidente> remote) {
  final byId = <String, Incidente>{};

  for (final item in local) {
    if (item.estadoSync == 'SINCRONIZADO' && item.serverId != null) {
      byId.putIfAbsent(
        item.serverId!,
        () => Incidente(
          id: item.serverId!,
          serverId: item.serverId,
          estado: item.estado,
          descripcion: item.descripcion,
          latitud: item.latitud,
          longitud: item.longitud,
          direccion: item.direccion,
          reportadoAt: item.reportadoAt,
          vehiculoId: item.vehiculoId,
          estadoSync: item.estadoSync,
        ),
      );
      continue;
    }
    byId.putIfAbsent(item.trackingId, () => item);
  }

  for (final item in remote) {
    byId[item.trackingId] = item;
  }

  final merged = byId.values.toList()
    ..sort((a, b) => _incidenteSortKey(b).compareTo(_incidenteSortKey(a)));
  return merged;
}

final incidentesProvider = FutureProvider<List<Incidente>>((ref) async {
  final localRows = await LocalDb.allLocal();
  final local = localRows.map(Incidente.fromLocalRow).toList();

  if (!await ref.watch(authServiceProvider).isLoggedIn()) {
    return mergeIncidentes(
      local.where((i) => i.estadoSync != 'SINCRONIZADO').toList(),
      const [],
    );
  }

  try {
    final remote = await ref.watch(incidenteApiProvider).list(limit: 100);
    return mergeIncidentes(local, remote);
  } catch (_) {
    return mergeIncidentes(local, const []);
  }
});

final asignacionesProvider =
    FutureProvider<List<Asignacion>>((ref) async {
  if (!await ref.watch(authServiceProvider).isLoggedIn()) return [];
  return ref.watch(tallerApiProvider).misAsignaciones();
});

/// Invalida providers de sesión tras un 401 (token expirado o inválido).
void invalidateAuthProviders(WidgetRef ref) {
  InAppNotificationService.stop();
  ref.invalidate(authStateProvider);
  ref.invalidate(profileProvider);
  ref.invalidate(vehiculosProvider);
  ref.invalidate(incidentesProvider);
  ref.invalidate(loginProvider);
}
