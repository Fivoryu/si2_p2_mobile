import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/app_providers.dart';
import '../services/sync_service.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    _trySync();
  }

  Future<void> _trySync() async {
    await SyncService.syncNow();
    if (mounted) ref.invalidate(incidentesProvider);
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidentesAsync = ref.watch(incidentesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              await _trySync();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _trySync,
        child: incidentesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Sin incidentes registrados')),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                final isPending =
                    item.isLocal && item.estadoSync == 'PENDIENTE';
                final trackId = item.isLocal ? item.id : item.id;

                return ListTile(
                  leading: Icon(
                    isPending ? Icons.schedule : Icons.check_circle_outline,
                    color: isPending ? Colors.orange : null,
                  ),
                  title: Text(
                    item.descripcion ?? 'Sin descripción',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.estado}${isPending ? ' · pendiente sync' : ''}\n'
                    '${_formatDate(item.reportadoAt)}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/tracking/$trackId'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
