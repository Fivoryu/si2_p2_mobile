import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/api_errors.dart';
import '../data/models/asignacion.dart';
import '../shared/widgets/simulacion_dialog.dart';
import '../providers/app_providers.dart';
import '../services/location_service.dart';
import '../services/technician_location_broadcaster.dart';

class TallerHomeScreen extends ConsumerStatefulWidget {
  const TallerHomeScreen({super.key});

  @override
  ConsumerState<TallerHomeScreen> createState() => _TallerHomeScreenState();
}

class _TallerHomeScreenState extends ConsumerState<TallerHomeScreen>
    with SingleTickerProviderStateMixin {
  final _simulandoAsignaciones = <String, bool>{};
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TechnicianLocationBroadcaster.instance.configure(
        api: ref.read(incidenteApiProvider),
        getAssignments: () => ref.read(asignacionesProvider).maybeWhen(
              data: (items) => items,
              orElse: () => const <Asignacion>[],
            ),
      );
    });
  }

  @override
  void dispose() {
    TechnicianLocationBroadcaster.instance.stop();
    _searchCtrl.dispose();
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

  Future<void> _simularRuta(Asignacion asig) async {
    final incidenteId = asig.incidenteId;
    if (incidenteId.isEmpty) return;

    final duracionMin = await pedirDuracionSimulacion(context);
    if (duracionMin == null) return;

    setState(() => _simulandoAsignaciones[asig.id] = true);

    try {
      final loc = LocationService();
      final pos = await loc.current();
      await ref.read(incidenteApiProvider).iniciarSimulacion(
        incidenteId,
        duracionSimMin: duracionMin,
        usarFake: loc.usarFakeGps,
        usarOsrm: true,
        origenLat: pos.latitude,
        origenLng: pos.longitude,
      );

      TechnicianLocationBroadcaster.instance.stop();

      await ref.read(incidenteApiProvider).cambiarEstado(
        incidenteId,
        'EN_CAMINO',
      );

      ref.invalidate(asignacionesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Simulación iniciada. El técnico se está moviendo.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${messageFromDio(e)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _simulandoAsignaciones[asig.id] = false);
      }
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
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings/tecnico'),
          ),
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
            Tab(text: 'Candidatos'),
            Tab(text: 'Asignadas'),
            Tab(text: 'Aceptadas'),
            Tab(text: 'Rechazadas'),
            Tab(text: 'Todas'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Buscar emergencia...',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.6),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: asignacionesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(messageFromDio(e))),
              data: (all) {
                TechnicianLocationBroadcaster.instance.syncWithAssignments(all);
                final filtered = _visibleList(all);
                if (filtered.isEmpty) {
                  return ListView(
                    children: [
                      SizedBox(height: _searchQuery.isEmpty ? 120 : 80),
                      Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'Sin asignaciones'
                              : 'Sin resultados para "$_searchQuery"',
                        ),
                      ),
                    ],
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(asignacionesProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final asig = filtered[index];
                      return _AsignacionCard(
                        asignacion: asig,
                        onTap: () => context.push('/asignacion/${asig.id}'),
                        onSimular: () => _simularRuta(asig),
                        simulando: _simulandoAsignaciones[asig.id] ?? false,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Asignacion> _filterByTab(List<Asignacion> all) {
    switch (_tabController.index) {
      case 0:
        return all.where((a) => a.esCandidato).toList();
      case 1:
        return all.where((a) => !a.esCandidato && (a.estado == 'ASIGNADO' || a.estado == 'PENDIENTE')).toList();
      case 2:
        return all.where((a) => !a.esCandidato && a.estado == 'ACEPTADO').toList();
      case 3:
        return all.where((a) => !a.esCandidato && a.estado == 'RECHAZADO').toList();
      default:
        return all;
    }
  }

  List<Asignacion> _visibleList(List<Asignacion> all) {
    final byTab = _filterByTab(all)
      ..sort((a, b) => b.sortDate.compareTo(a.sortDate));

    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return byTab;

    return byTab.where((a) => _matchesSearch(a, q)).toList();
  }

  bool _matchesSearch(Asignacion a, String q) {
    final text = [
      a.incidenteDescripcion,
      a.incidenteDireccion,
      a.incidenteResumenIa,
      a.incidentePrioridad,
      a.incidenteEstado,
      a.dificultad,
      Asignacion.estadoLabel(a.estado),
    ].whereType<String>().join(' ').toLowerCase();
    return text.contains(q);
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

String _formatCardDate(Asignacion asignacion) {
  final raw = asignacion.incidenteReportadoAt ??
      asignacion.asignadoAt ??
      asignacion.respondidoAt;
  return Asignacion.formatDate(raw);
}

class _AsignacionCard extends StatelessWidget {
  const _AsignacionCard({
    required this.asignacion,
    required this.onTap,
    required this.onSimular,
    required this.simulando,
  });

  final Asignacion asignacion;
  final VoidCallback onTap;
  final VoidCallback onSimular;
  final bool simulando;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final estadoColor = asignacion.esCandidato
        ? Colors.amber.shade700
        : switch (asignacion.estado) {
          'ASIGNADO' || 'PENDIENTE' => colorScheme.tertiary,
          'ACEPTADO' => colorScheme.primary,
          'RECHAZADO' => colorScheme.error,
          _ => colorScheme.outline,
        };

    final iconData = asignacion.esCandidato
        ? Icons.lightbulb
        : switch (asignacion.estado) {
            'ASIGNADO' || 'PENDIENTE' => Icons.pending_actions,
            'ACEPTADO' => Icons.check_circle,
            'RECHAZADO' => Icons.cancel,
            _ => Icons.help,
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
                      iconData,
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
                          _formatCardDate(asignacion),
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
                      Asignacion.estadoLabel(asignacion.estado, esCandidato: asignacion.esCandidato),
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
              if (asignacion.estado == 'ACEPTADO') ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (simulando)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Simulando...',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      )
                    else
                      FilledButton.icon(
                        onPressed: onSimular,
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Simular ruta'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(fontSize: 13),
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
