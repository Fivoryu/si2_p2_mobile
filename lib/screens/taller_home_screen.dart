import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/api_errors.dart';
import '../data/models/asignacion.dart';
import '../providers/app_providers.dart';

class TallerHomeScreen extends ConsumerStatefulWidget {
  const TallerHomeScreen({super.key});

  @override
  ConsumerState<TallerHomeScreen> createState() => _TallerHomeScreenState();
}

class _TallerHomeScreenState extends ConsumerState<TallerHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final asignacionesAsync = ref.watch(asignacionesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Taller'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _showNotificaciones(context),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.push('/profile'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Asignadas'),
            Tab(text: 'Aceptadas'),
            Tab(text: 'Rechazadas'),
            Tab(text: 'Todas'),
          ],
        ),
      ),
      body: asignacionesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(messageFromDio(e))),
        data: (all) {
          final filtered = _filterByTab(all);
          if (filtered.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('Sin asignaciones')),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(asignacionesProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final asig = filtered[index];
                return _AsignacionCard(
                  asignacion: asig,
                  onTap: () => context.push('/asignacion/${asig.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }

  List<Asignacion> _filterByTab(List<Asignacion> all) {
    switch (_tabController.index) {
      case 0:
        return all.where((a) => a.estado == 'ASIGNADO').toList();
      case 1:
        return all.where((a) => a.estado == 'ACEPTADO').toList();
      case 2:
        return all.where((a) => a.estado == 'RECHAZADO').toList();
      default:
        return all;
    }
  }

  void _showNotificaciones(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('Notificaciones',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder(
                  future: ref.read(tallerApiProvider).misNotificaciones(),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snap.hasData || snap.data!.isEmpty) {
                      return const Center(child: Text('Sin notificaciones'));
                    }
                    return ListView.separated(
                      controller: scrollController,
                      itemCount: snap.data!.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final n = snap.data![i];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              n['canal'] == 'PUSH'
                                  ? Icons.notifications_active
                                  : Icons.notifications,
                            ),
                          ),
                          title: Text(n['titulo'] ?? ''),
                          subtitle: Text(n['mensaje'] ?? ''),
                          trailing: Text(
                            _formatDate(n['creada_at']?.toString()),
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AsignacionCard extends StatelessWidget {
  const _AsignacionCard({required this.asignacion, required this.onTap});

  final Asignacion asignacion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final estadoColor = switch (asignacion.estado) {
      'ASIGNADO' => colorScheme.tertiary,
      'ACEPTADO' => colorScheme.primary,
      'RECHAZADO' => colorScheme.error,
      _ => colorScheme.outline,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: estadoColor.withValues(alpha: 0.15),
                    child: Icon(
                      switch (asignacion.estado) {
                        'ASIGNADO' => Icons.pending_actions,
                        'ACEPTADO' => Icons.check_circle,
                        'RECHAZADO' => Icons.cancel,
                        _ => Icons.help,
                      },
                      color: estadoColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asignacion.incidenteDescripcion ?? 'Sin descripción',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Asignacion.formatDate(asignacion.respondidoAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: estadoColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      Asignacion.estadoLabel(asignacion.estado),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: estadoColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (asignacion.incidenteDireccion != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        asignacion.incidenteDireccion!,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (asignacion.incidentePrioridad != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.flag,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Prioridad: ${asignacion.incidentePrioridad}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
