import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/api_errors.dart';
import '../data/models/incidente.dart';
import '../providers/app_providers.dart';
import '../services/sync_service.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _trySync();
  }

  Future<void> _trySync() async {
    setState(() => _syncing = true);
    try {
      await SyncService.syncNow();
    } catch (_) {
      // offline or error — local list still shown
    }
    if (mounted) {
      ref.invalidate(incidentesProvider);
      setState(() => _syncing = false);
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

  void _openIncident(Incidente item) {
    final trackId = item.trackingId;
    if (item.isLocal && item.isPendingSync) {
      context.push('/incident/${item.id}', extra: item);
    } else if (item.estado == 'PENDIENTE' ||
        item.estado == 'BUSCANDO_TALLER' ||
        item.estado == 'TALLER_ASIGNADO' ||
        item.estado == 'EN_CAMINO' ||
        item.estado == 'EN_ATENCION') {
      context.push('/tracking/$trackId');
    } else {
      context.push('/incident/$trackId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidentesAsync = ref.watch(incidentesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
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
                final isPending = item.isPendingSync;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: isPending
                          ? colorScheme.tertiaryContainer
                          : colorScheme.primaryContainer,
                      child: Icon(
                        isPending
                            ? Icons.schedule
                            : Icons.emergency_outlined,
                        color: isPending
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
                            Text(Incidente.estadoLabel(item.estado)),
                            if (item.prioridad != null) ...[
                              const Text(' · '),
                              Text(item.prioridad!),
                            ],
                            if (isPending) ...[
                              const Text(' · '),
                              Text(
                                'pendiente sync',
                                style: TextStyle(color: colorScheme.tertiary),
                              ),
                            ],
                          ],
                        ),
                        Text(_formatDate(item.reportadoAt)),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openIncident(item),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
