import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_errors.dart';
import '../data/models/asignacion.dart';
import '../data/models/incidente.dart';
import '../providers/app_providers.dart';
import '../services/location_service.dart';
import '../services/technician_location_broadcaster.dart';
import '../shared/widgets/asignacion_live_map.dart';
import '../shared/widgets/simulacion_dialog.dart';

class AsignacionDetailScreen extends ConsumerStatefulWidget {
  const AsignacionDetailScreen({super.key, required this.asignacionId});

  final String asignacionId;

  @override
  ConsumerState<AsignacionDetailScreen> createState() =>
      _AsignacionDetailScreenState();
}

class _AsignacionDetailScreenState extends ConsumerState<AsignacionDetailScreen> {
  bool _loading = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) ref.invalidate(asignacionesProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _aceptarCandidato(Asignacion asig) async {
    if (!mounted) return;
    final precioSugerido = asig.precioSugerido;
    final tiempoSugerido = asig.tiempoTotalMin;
    final precioCtrl = TextEditingController(
      text: precioSugerido?.toStringAsFixed(2) ?? '',
    );
    final tiempoCtrl = TextEditingController(
      text: tiempoSugerido?.toString() ?? '',
    );
    final comentarioCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar oferta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (precioSugerido != null)
              Text('Precio sugerido: ${precioSugerido.toStringAsFixed(2)} BOB'),
            const SizedBox(height: 12),
            TextField(
              controller: precioCtrl,
              decoration: const InputDecoration(
                labelText: 'Precio ofertado (BOB)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tiempoCtrl,
              decoration: const InputDecoration(
                labelText: 'Tiempo estimado (min)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: comentarioCtrl,
              decoration: const InputDecoration(
                labelText: 'Comentario opcional',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar oferta'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await ref.read(tallerApiProvider).aceptarCandidato(
            asig.id,
            precioOfertado: double.tryParse(precioCtrl.text.replaceAll(',', '.')),
            tiempoEstimadoMin: int.tryParse(tiempoCtrl.text),
            comentario: comentarioCtrl.text.trim().isNotEmpty
                ? comentarioCtrl.text.trim()
                : null,
          );
      ref.invalidate(asignacionesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oferta enviada al cliente')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageFromDio(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rechazarCandidato(Asignacion asig) async {
    final motiveCtrl = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar oportunidad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Deseas rechazar esta oportunidad? (opcional)'),
            const SizedBox(height: 12),
            TextField(
              controller: motiveCtrl,
              decoration: const InputDecoration(
                hintText: 'Motivo (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, motiveCtrl.text.trim()),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await ref.read(tallerApiProvider).rechazarCandidato(
            asig.id,
            motivo: motivo?.isNotEmpty == true ? motivo : null,
          );
      ref.invalidate(asignacionesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oportunidad rechazada')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageFromDio(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _aceptar(Asignacion asig) async {
    if (!mounted) return;
    final precioSugerido = asig.precioSugerido;
    final tiempoSugerido = asig.tiempoTotalMin ?? asig.tiempoLlegadaMin;
    final precioCtrl = TextEditingController(
      text: precioSugerido?.toStringAsFixed(2) ?? '',
    );
    final tiempoCtrl = TextEditingController(
      text: tiempoSugerido?.toString() ?? '',
    );
    final comentarioCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar oferta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (precioSugerido != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Precio sugerido',
                        style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                              color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${precioSugerido.toStringAsFixed(2)} BOB',
                        style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                            ),
                      ),
                      if (asig.precioMin != null && asig.precioMax != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Rango: ${asig.precioMin!.toStringAsFixed(2)} – ${asig.precioMax!.toStringAsFixed(2)} BOB',
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                      if (asig.comisionPlataforma != null && asig.montoTaller != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Comisión plataforma (10%): ${asig.comisionPlataforma!.toStringAsFixed(2)} BOB · '
                          'Taller recibe: ${asig.montoTaller!.toStringAsFixed(2)} BOB',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ],
                      if (asig.dificultad != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Dificultad: ${asig.dificultad}',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: precioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Precio ofertado (BOB)',
                  border: OutlineInputBorder(),
                  helperText: 'Puede ajustar el precio sugerido',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tiempoCtrl,
                decoration: InputDecoration(
                  labelText: 'Tiempo estimado (min)',
                  border: const OutlineInputBorder(),
                  helperText: tiempoSugerido != null
                      ? 'Sugerido: $tiempoSugerido min'
                      : null,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: comentarioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Comentario opcional',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar oferta'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await ref.read(tallerApiProvider).aceptarConOferta(
            asig.id,
            precioOfertado: double.tryParse(precioCtrl.text.replaceAll(',', '.')),
            tiempoEstimadoMin: int.tryParse(tiempoCtrl.text),
            comentario: comentarioCtrl.text.trim().isNotEmpty
                ? comentarioCtrl.text.trim()
                : null,
          );
      ref.invalidate(asignacionesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oferta enviada al cliente')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageFromDio(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rechazar(Asignacion asig) async {
    final motiveCtrl = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Cuál es el motivo del rechazo? (opcional)'),
            const SizedBox(height: 12),
            TextField(
              controller: motiveCtrl,
              decoration: const InputDecoration(
                hintText: 'Ej: demasiado lejos, falta de repuestos',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, motiveCtrl.text.trim()),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    setState(() => _loading = true);
    try {
      if (asig.esOportunidadCandidato) {
        await ref.read(tallerApiProvider).rechazarCandidato(
              asig.id,
              motivo: motivo?.isNotEmpty == true ? motivo : null,
            );
      } else {
        await ref.read(tallerApiProvider).rechazar(
              asig.id,
              motivo: motivo?.isNotEmpty == true ? motivo : null,
            );
      }
      ref.invalidate(asignacionesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud rechazada')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageFromDio(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asignacionesAsync = ref.watch(asignacionesProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de asignación')),
      body: asignacionesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(messageFromDio(e))),
        data: (list) {
          final asig = list.where((a) => a.id == widget.asignacionId).firstOrNull;
          if (asig == null) {
            return const Center(child: Text('Asignación no encontrada'));
          }

          TechnicianLocationBroadcaster.instance.configure(
            api: ref.read(incidenteApiProvider),
            getAssignments: () => ref.read(asignacionesProvider).maybeWhen(
                  data: (items) => items,
                  orElse: () => const <Asignacion>[],
                ),
          );
          TechnicianLocationBroadcaster.instance.syncWithAssignments(list);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                asig.incidenteEstado ?? '—',
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (asig.incidentePrioridad != null)
                              Chip(
                                label: Text(asig.incidentePrioridad!),
                                avatar: const Icon(Icons.flag, size: 16),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Descripción del incidente',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          asig.incidenteDescripcion ?? 'Sin descripción',
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        if (asig.incidenteDireccion != null)
                          _InfoRow(
                            icon: Icons.location_on,
                            label: 'Dirección',
                            value: asig.incidenteDireccion!,
                          ),
                        if (asig.incidenteResumenIa != null) ...[
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.summarize,
                            label: 'Resumen IA',
                            value: asig.incidenteResumenIa!,
                          ),
                        ],
                        if (asig.precioSugerido != null) ...[
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.payments,
                            label: 'Precio sugerido',
                            value:
                                '${asig.precioSugerido!.toStringAsFixed(2)} BOB',
                          ),
                          if (asig.precioMin != null && asig.precioMax != null)
                            _InfoRow(
                              icon: Icons.tune,
                              label: 'Rango permitido',
                              value:
                                  '${asig.precioMin!.toStringAsFixed(2)} – ${asig.precioMax!.toStringAsFixed(2)} BOB',
                            ),
                          if (asig.comisionPlataforma != null)
                            _InfoRow(
                              icon: Icons.percent,
                              label: 'Comisión plataforma',
                              value:
                                  '${asig.comisionPlataforma!.toStringAsFixed(2)} BOB (10%)',
                            ),
                        ],
                        if (asig.distanciaKm != null) ...[
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.route,
                            label: 'Distancia',
                            value:
                                '${asig.distanciaKm!.toStringAsFixed(2)} km',
                          ),
                        ],
                        if (asig.tiempoLlegadaMin != null) ...[
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.schedule,
                            label: 'Llegada estimada',
                            value: '${asig.tiempoLlegadaMin} min',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (asig.incidenteLatitud != null &&
                    asig.incidenteLongitud != null &&
                    (asig.incidenteEstado == 'EN_CAMINO' ||
                        asig.incidenteEstado == 'TALLER_ASIGNADO')) ...[
                  const SizedBox(height: 20),
                  AsignacionLiveMap(
                    incidenteId: asig.incidenteId,
                    clienteLat: asig.incidenteLatitud!,
                    clienteLng: asig.incidenteLongitud!,
                  ),
                ],
                const SizedBox(height: 20),
                if (asig.esOportunidadCandidato) ...[
                  Card(
                    color: Colors.amber.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.amber.shade700),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Oportunidad de servicio — este taller fue sugerido como candidato cercano.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Acciones',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : () => _aceptarCandidato(asig),
                      icon: _loading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle),
                      label: const Text('Enviar Oferta'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : () => _rechazarCandidato(asig),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Rechazar'),
                    ),
                  ),
                ],
                if (asig.estado == 'ASIGNADO' && !asig.esOportunidadCandidato) ...[
                  Text(
                    'Acciones disponibles',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading
                          ? null
                          : () => _aceptar(asig),
                      icon: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle),
                      label: const Text('Enviar Oferta'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : () => _rechazar(asig),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Rechazar'),
                    ),
                  ),
                ],
                if (asig.estado == 'ACEPTADO') ...[
                  const SizedBox(height: 16),
                  _StatusActions(
                    incidenteEstado: asig.incidenteEstado ?? 'TALLER_ASIGNADO',
                    incidenteId: asig.incidenteId,
                    loading: _loading,
                    onLoadingChange: (v) => setState(() => _loading = v),
                    onActionDone: () {
                      ref.invalidate(asignacionesProvider);
                    },
                  ),
                ],
                if (asig.motivoRechazo != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Motivo del rechazo:',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(asig.motivoRechazo!),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusActions extends ConsumerWidget {
  const _StatusActions({
    required this.incidenteEstado,
    required this.incidenteId,
    required this.loading,
    required this.onLoadingChange,
    required this.onActionDone,
  });

  final String incidenteEstado;
  final String incidenteId;
  final bool loading;
  final ValueChanged<bool> onLoadingChange;
  final VoidCallback onActionDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    if (incidenteEstado == 'FINALIZADO' || incidenteEstado == 'PAGADO') {
      return Card(
        color: colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  incidenteEstado == 'FINALIZADO'
                      ? 'Servicio finalizado'
                      : 'Servicio pagado',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acciones del técnico',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (incidenteEstado == 'TALLER_ASIGNADO') ...[
          _ActionButton(
            label: 'Enviar mi ubicación',
            icon: Icons.my_location,
            color: colorScheme.secondary,
            onPressed: loading ? null : () => _enviarUbicacion(context, ref),
          ),
          const SizedBox(height: 8),
          _ActionButton(
            label: 'Iniciar Camino',
            icon: Icons.directions_car,
            color: colorScheme.primary,
            onPressed: loading
                ? null
                : () => _cambiarEstado(context, ref, 'EN_CAMINO'),
          ),
          const SizedBox(height: 8),
          _ActionButton(
            label: 'Simular Ruta + En Camino',
            icon: Icons.play_arrow,
            color: colorScheme.tertiary,
            onPressed: loading
                ? null
                : () => _simularYRuta(context, ref),
          ),
        ],
        if (incidenteEstado == 'EN_CAMINO') ...[
          _ActionButton(
            label: 'Enviar mi ubicación',
            icon: Icons.my_location,
            color: colorScheme.secondary,
            onPressed: loading ? null : () => _enviarUbicacion(context, ref),
          ),
          const SizedBox(height: 8),
          _ActionButton(
            label: 'Simular Ruta (reiniciar)',
            icon: Icons.play_arrow,
            color: colorScheme.tertiary,
            onPressed: loading
                ? null
                : () => _simularYRuta(context, ref),
          ),
          const SizedBox(height: 8),
          _ActionButton(
            label: 'Marcar Llegada',
            icon: Icons.place,
            color: colorScheme.secondary,
            onPressed: loading
                ? null
                : () => _cambiarEstado(context, ref, 'EN_ATENCION'),
          ),
        ],
        if (incidenteEstado == 'EN_ATENCION') ...[
          Card(
            color: colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Técnico en el lugar — ${Incidente.estadoLabel(incidenteEstado)}',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _ActionButton(
            label: 'Finalizar Servicio',
            icon: Icons.check_circle,
            color: colorScheme.primary,
            onPressed: loading
                ? null
                : () => _cambiarEstado(context, ref, 'FINALIZADO'),
          ),
        ],
      ],
    );
  }

  Future<void> _enviarUbicacion(BuildContext context, WidgetRef ref) async {
    onLoadingChange(true);
    try {
      final loc = LocationService();
      final pos = await loc.current();
      await ref.read(incidenteApiProvider).enviarUbicacion(
            incidenteId,
            lat: pos.latitude,
            lng: pos.longitude,
            esFake: loc.usarFakeGps,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc.usarFakeGps
                  ? 'Ubicación simulada enviada'
                  : 'Ubicación GPS enviada',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${messageFromDio(e)}')),
        );
      }
    } finally {
      onLoadingChange(false);
    }
  }

  Future<void> _cambiarEstado(BuildContext context, WidgetRef ref, String nuevoEstado) async {
    if (incidenteEstado == nuevoEstado) {
      onActionDone();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Estado actual: ${Incidente.estadoLabel(nuevoEstado)}',
            ),
          ),
        );
      }
      return;
    }

    onLoadingChange(true);
    try {
      await ref.read(incidenteApiProvider).cambiarEstado(incidenteId, nuevoEstado);
      if (nuevoEstado == 'EN_CAMINO' && context.mounted) {
        await _enviarUbicacion(context, ref);
      }
      onActionDone();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Estado: ${Incidente.estadoLabel(nuevoEstado)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${messageFromDio(e)}')),
        );
      }
    } finally {
      onLoadingChange(false);
    }
  }

  Future<void> _simularYRuta(BuildContext context, WidgetRef ref) async {
    final duracionMin = await pedirDuracionSimulacion(context);
    if (duracionMin == null) return;

    onLoadingChange(true);
    try {
      final loc = LocationService();
      final pos = await loc.current();
      final result = await ref.read(incidenteApiProvider).iniciarSimulacion(
        incidenteId,
        duracionSimMin: duracionMin,
        usarFake: loc.usarFakeGps,
        usarOsrm: true,
        origenLat: pos.latitude,
        origenLng: pos.longitude,
      );
      TechnicianLocationBroadcaster.instance.stop();

      if (incidenteEstado == 'TALLER_ASIGNADO') {
        await ref.read(incidenteApiProvider).cambiarEstado(incidenteId, 'EN_CAMINO');
      }

      onActionDone();
      if (context.mounted) {
        final motor = result['motor_ruta'] as String? ?? 'calles';
        final motorLabel = motor == 'osrm' ? 'OSRM (calles reales)' : 'simulada';
        final vel = (result['velocidad_sim_kmh'] as num?)?.toDouble();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ruta $motorLabel · ~${duracionMin.toStringAsFixed(0)} min'
              '${vel != null ? ' (${vel.toStringAsFixed(0)} km/h sim.)' : ''}',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${messageFromDio(e)}')),
        );
      }
    } finally {
      onLoadingChange(false);
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(value),
            ],
          ),
        ),
      ],
    );
  }
}
