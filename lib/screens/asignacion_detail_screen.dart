import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_errors.dart';
import '../providers/app_providers.dart';

class AsignacionDetailScreen extends ConsumerStatefulWidget {
  const AsignacionDetailScreen({super.key, required this.asignacionId});

  final String asignacionId;

  @override
  ConsumerState<AsignacionDetailScreen> createState() =>
      _AsignacionDetailScreenState();
}

class _AsignacionDetailScreenState extends ConsumerState<AsignacionDetailScreen> {
  bool _loading = false;

  Future<void> _aceptar(double? precioSugerido, int? tiempoSugerido) async {
    if (!mounted) return;
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
      await ref.read(tallerApiProvider).aceptarConOferta(
            widget.asignacionId,
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

  Future<void> _rechazar() async {
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
      await ref.read(tallerApiProvider).rechazar(
            widget.asignacionId,
            motivo: motivo?.isNotEmpty == true ? motivo : null,
          );
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
                const SizedBox(height: 20),
                if (asig.estado == 'ASIGNADO') ...[
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
                          : () => _aceptar(
                                asig.precioSugerido,
                                asig.tiempoLlegadaMin,
                              ),
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
                      onPressed: _loading ? null : _rechazar,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Rechazar'),
                    ),
                  ),
                ],
                if (asig.estado == 'ACEPTADO') ...[
                  Card(
                    color: colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Esta solicitud ya fue aceptada. '
                              'El conductor está siendo notificado.',
                            ),
                          ),
                        ],
                      ),
                    ),
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
