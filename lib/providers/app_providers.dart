import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dio_client.dart';
import '../data/api/auth_api.dart';
import '../data/api/incidente_api.dart';
import '../data/api/usuario_api.dart';
import '../data/api/vehiculo_api.dart';
import '../data/models/auth_session.dart';
import '../data/models/incidente.dart';
import '../data/models/usuario.dart';
import '../data/models/vehiculo.dart';
import '../data/local_db.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final dioProvider = Provider((ref) => buildDio());

final authApiProvider = Provider((ref) => AuthApi(ref.watch(dioProvider)));

final incidenteApiProvider =
    Provider((ref) => IncidenteApi(ref.watch(dioProvider)));

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

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await ref.read(authServiceProvider).login(
            email: email,
            password: password,
          );
      ref.invalidate(authStateProvider);
      ref.invalidate(profileProvider);
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
  return ref.watch(vehiculoApiProvider).list();
});

final incidentesProvider = FutureProvider<List<Incidente>>((ref) async {
  final localRows = await LocalDb.allLocal();
  final local = localRows.map(Incidente.fromLocalRow).toList();

  if (!await ref.watch(authServiceProvider).isLoggedIn()) {
    return local;
  }

  try {
    final remote = await ref.watch(incidenteApiProvider).list();
    final remoteIds = remote.map((i) => i.id).toSet();
    final pendingLocal = local.where(
      (i) => i.estadoSync == 'PENDIENTE' || !remoteIds.contains(i.id),
    );
    return [...pendingLocal, ...remote];
  } catch (_) {
    return local;
  }
});
