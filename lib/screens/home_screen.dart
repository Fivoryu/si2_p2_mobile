import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../data/local_db.dart';
import '../data/models/incidente.dart';
import '../providers/app_providers.dart';
import '../services/location_service.dart';
import '../services/sync_service.dart';
import '../shared/widgets/location_map.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Position? _position;
  String? _locationError;
  bool _loadingLocation = true;
  String? _lastShownMessage;

  @override
  void initState() {
    super.initState();
    _loadLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _showSuccessMessageIfAny();
      if (await SyncService.hasConnectivity()) {
        final n = await SyncService.syncNow();
        if (n > 0 && mounted) ref.invalidate(incidentesProvider);
      }
      if (mounted) ref.invalidate(incidentesProvider);
    });
  }

  void _showSuccessMessageIfAny() {
    final message = GoRouterState.of(context).extra;
    if (message is! String || message.isEmpty || message == _lastShownMessage) {
      return;
    }
    _lastShownMessage = message;
    final pending = message.contains('cuando haya conexión');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(
              pending ? Icons.schedule : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Future<void> _openIncident(
    BuildContext context,
    Incidente item,
    bool isActive,
  ) async {
    if (item.needsSync) {
      if (await SyncService.hasConnectivity()) {
        try {
          final serverId = await SyncService.ensureSynced(item.id);
          if (!context.mounted) return;
          ref.invalidate(incidentesProvider);
          if (serverId != null) {
            context.push('/tracking/$serverId');
            return;
          }
        } catch (_) {}
      }
      if (context.mounted) {
        context.push('/incident/${item.id}', extra: item);
      }
      return;
    }

    final serverId = await LocalDb.serverIdFor(item.trackingId);
    final trackId = serverId ?? item.trackingId;
    if (!context.mounted) return;
    if (isActive) {
      context.push('/tracking/$trackId');
    } else {
      context.push('/incident/$trackId');
    }
  }

  Future<void> _loadLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });
    try {
      final pos = await LocationService().current();
      if (mounted) {
        setState(() {
          _position = pos;
          _loadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = e.toString();
          _loadingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final successMessage = GoRouterState.of(context).extra;
    if (successMessage is String &&
        successMessage.isNotEmpty &&
        successMessage != _lastShownMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSuccessMessageIfAny());
    }

    final profileAsync = ref.watch(profileProvider);
    final incidentesAsync = ref.watch(incidentesProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/history'),
            tooltip: 'Historial',
          ),
          IconButton(
            icon: const Icon(Icons.directions_car),
            onPressed: () => context.push('/vehicles'),
            tooltip: 'Vehículos',
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.push('/profile'),
            tooltip: 'Perfil',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              profileAsync.when(
                data: (u) => Text(
                  'Hola, ${u?.nombre ?? 'Conductor'}',
                  style: theme.textTheme.headlineSmall,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => Text(
                  'Conductor',
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '¿Necesita asistencia en carretera?',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 0,
                  child: _loadingLocation
                      ? const Center(child: CircularProgressIndicator())
                      : _locationError != null
                          ? Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.location_off,
                                    size: 56,
                                    color: colorScheme.error,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No se pudo obtener la ubicación',
                                    style: theme.textTheme.titleMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _locationError!,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.tonal(
                                    onPressed: _loadLocation,
                                    child: const Text('Reintentar GPS'),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: LocationMap(
                                    latitude: _position!.latitude,
                                    longitude: _position!.longitude,
                                    height: double.infinity,
                                    borderRadius: 0,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.my_location,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Ubicación actual',
                                              style:
                                                  theme.textTheme.titleSmall,
                                            ),
                                            Text(
                                              '${_position!.latitude.toStringAsFixed(5)}, '
                                              '${_position!.longitude.toStringAsFixed(5)}',
                                              style:
                                                  theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 16),
              incidentesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (items) {
                  if (items.isEmpty) return const SizedBox.shrink();
                  final latest = items.first;
                  final isActive = latest.estado != 'FINALIZADO' &&
                      latest.estado != 'PAGADO' &&
                      latest.estado != 'CANCELADO';
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        isActive ? Icons.emergency : Icons.history,
                        color: isActive
                            ? colorScheme.error
                            : colorScheme.primary,
                      ),
                      title: Text(
                        isActive ? 'Emergencia reciente' : 'Última emergencia',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        isActive && latest.estado == 'BUSCANDO_TALLER'
                            ? '${Incidente.estadoLabel(latest.estado)} · Toca para ver ofertas\n'
                              '${latest.descripcion ?? 'Sin descripción'}'
                            : '${Incidente.estadoLabel(latest.estado)} · '
                              '${latest.descripcion ?? 'Sin descripción'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openIncident(context, latest, isActive),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.push('/new-incident'),
                icon: const Icon(Icons.emergency, size: 28),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Nueva emergencia',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/history'),
                icon: const Icon(Icons.history),
                label: const Text('Ver historial'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
