import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/api_errors.dart';
import '../data/models/incidente.dart';
import '../providers/app_providers.dart';
import '../data/local_db.dart';
import '../services/sync_service.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _syncing = false;
  final Set<String> _syncingIds = {};

  @override
  void initState() {
    super.initState();
    _trySync();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showMessageIfAny());
  }

  void _showMessageIfAny() {
    final message = GoRouterState.of(context).extra;
    if (message is! String || message.isEmpty || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _trySync() async {
    setState(() => _syncing = true);
    try {
      final n = await SyncService.syncNow();
      if (mounted && n > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$n emergencia(s) sincronizada(s)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageFromDio(e))),
        );
      }
    }
    if (mounted) {
      ref.invalidate(incidentesProvider);
      setState(() => _syncing = false);
    }
  }

  Future<void> _retryOne(Incidente item) async {
    if (_syncingIds.contains(item.id)) return;
    setState(() => _syncingIds.add(item.id));
    try {
      final ok = await SyncService.syncOne(item.id);
      if (!mounted) return;
      ref.invalidate(incidentesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Emergencia sincronizada'
                : 'No se pudo sincronizar la emergencia',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageFromDio(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _syncingIds.remove(item.id));
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      return DateFormat('dd/MM/yyyy HH:mm')
          .format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  String? _syncBadge(Incidente item) {
    if (!item.isLocal) return null;
    if (item.isPendingSync) return 'pendiente sync';
    if (item.isErrorSync) return 'error sync';
    if (item.isSyncedLocal) return 'sincronizado';
    return null;
  }

  Color? _syncBadgeColor(Incidente item, ColorScheme scheme) {
    if (item.isErrorSync) return scheme.error;
    if (item.isPendingSync) return scheme.tertiary;
    if (item.isSyncedLocal) return scheme.primary;
    return null;
  }

  Future<void> _openIncident(Incidente item) async {
    if (item.needsSync) {
      if (await SyncService.hasConnectivity()) {
        try {
          final serverId = await SyncService.ensureSynced(item.id);
          if (!mounted) return;
          ref.invalidate(incidentesProvider);
          if (serverId != null) {
            context.push('/tracking/$serverId');
            return;
          }
        } catch (_) {}
      }
      if (mounted) {
        context.push('/incident/${item.id}', extra: item);
      }
      return;
    }

    final serverId = await LocalDb.serverIdFor(item.trackingId);
    final trackId = serverId ?? item.trackingId;
    if (!mounted) return;
    if (item.estado == 'PENDIENTE' ||
        item.estado == 'BUSCANDO_TALLER' ||
        item.estado == 'TALLER_ASIGNADO' ||
        item.estado == 'EN_CAMINO' ||
        item.estado == 'EN_ATENCION') {
      context.push('/tracking/$trackId');
    } else {
      context.push('/incident/$trackId');
    }
  }

  void _navigateBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidentesAsync = ref.watch(incidentesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _navigateBack();
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: _navigateBack,
        ),
        title: const Text('Historial'),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Sincronizar pendientes',
              onPressed: _trySync,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _trySync,
        child: incidentesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(messageFromDio(e))),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Sin incidentes registrados')),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final syncBadge = _syncBadge(item);
                final badgeColor = _syncBadgeColor(item, colorScheme);
                final isRetrying = _syncingIds.contains(item.id);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: item.isErrorSync
                          ? colorScheme.errorContainer
                          : item.isPendingSync
                              ? colorScheme.tertiaryContainer
                              : colorScheme.primaryContainer,
                      child: Icon(
                        item.isErrorSync
                            ? Icons.cloud_off
                            : item.isPendingSync
                                ? Icons.schedule
                                : Icons.emergency_outlined,
                        color: item.isErrorSync
                            ? colorScheme.onErrorContainer
                            : item.isPendingSync
                                ? colorScheme.onTertiaryContainer
                                : colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(
                      item.descripcion ?? 'Sin descripción',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                Incidente.estadoLabel(item.estado),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item.prioridad != null) ...[
                              const Text(' · '),
                              Text(item.prioridad!),
                            ],
                            if (syncBadge != null && badgeColor != null) ...[
                              const Text(' · '),
                              Text(
                                syncBadge,
                                style: TextStyle(color: badgeColor),
                              ),
                            ],
                          ],
                        ),
                        Text(_formatDate(item.reportadoAt)),
                      ],
                    ),
                    trailing: item.isErrorSync
                        ? isRetrying
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Reintentar sincronización',
                                onPressed: () => _retryOne(item),
                              )
                        : const Icon(Icons.chevron_right),
                    onTap: () => _openIncident(item),
                  ),
                );
              },
            );
          },
        ),
      ),
      ),
    );
  }
}
