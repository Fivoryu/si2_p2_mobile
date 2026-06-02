import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/api_errors.dart';
import '../data/models/incidente.dart';
import '../providers/app_providers.dart';

class IncidentDetailScreen extends ConsumerStatefulWidget {
  const IncidentDetailScreen({
    super.key,
    required this.incidentId,
    this.localIncident,
  });

  final String incidentId;
  final Incidente? localIncident;

  @override
  ConsumerState<IncidentDetailScreen> createState() =>
      _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends ConsumerState<IncidentDetailScreen> {
  IncidenteDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.localIncident != null &&
        widget.localIncident!.isPendingSync) {
      setState(() {
        _detail = IncidenteDetail(
          incidente: widget.localIncident!,
          evidencias: [],
        );
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await ref
          .read(incidenteApiProvider)
          .getById(widget.localIncident?.trackingId ?? widget.incidentId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = messageFromDio(e);
          _loading = false;
        });
      }
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

  Future<void> _cancel(String id) async {
    setState(() => _cancelling = true);
    try {
      await ref.read(incidenteApiProvider).cancel(id);
      ref.invalidate(incidentesProvider);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incidente cancelado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageFromDio(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _seleccionarOferta(OfertaTaller oferta) async {
    try {
      await ref.read(incidenteApiProvider).seleccionarOferta(oferta.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oferta seleccionada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageFromDio(e))),
        );
      }
    }
  }

  Future<void> _pagarOferta(OfertaTaller oferta) async {
    try {
      await ref.read(incidenteApiProvider).pagarMock(
            incidenteId: _detail!.incidente.trackingId,
            cotizacionId: oferta.id,
          );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pago registrado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageFromDio(e))),
        );
      }
    }
  }

  Future<void> _calificar() async {
    var estrellas = 5;
    final comentarioCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Calificar servicio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: estrellas,
              items: const [1, 2, 3, 4, 5]
                  .map((e) => DropdownMenuItem(value: e, child: Text('$e estrellas')))
                  .toList(),
              onChanged: (value) => estrellas = value ?? 5,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: comentarioCtrl,
              decoration: const InputDecoration(
                labelText: 'Comentario opcional',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(incidenteApiProvider).calificar(
            _detail!.incidente.trackingId,
            estrellas,
            comentario: comentarioCtrl.text.trim().isNotEmpty
                ? comentarioCtrl.text.trim()
                : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gracias por tu calificación')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageFromDio(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del incidente')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(theme, colorScheme),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme colorScheme) {
    final inc = _detail!.incidente;
    final trackId = inc.trackingId;
    final isActive = inc.estado != 'CANCELADO' &&
        inc.estado != 'FINALIZADO' &&
        inc.estado != 'PAGADO' &&
        inc.estado != 'NO_ATENDIDO';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          Incidente.estadoLabel(inc.estado),
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      if (inc.prioridad != null)
                        Chip(label: Text(inc.prioridad!)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_formatDate(inc.reportadoAt)),
                  if (inc.isPendingSync) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 18,
                          color: colorScheme.tertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Pendiente de sincronización',
                          style: TextStyle(color: colorScheme.tertiary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (inc.descripcion != null) ...[
            Text('Descripción', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(inc.descripcion!),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (inc.direccion != null ||
              inc.latitud != null && inc.longitud != null) ...[
            Text('Ubicación', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(inc.direccion ?? 'Coordenadas'),
                subtitle: inc.latitud != null
                    ? Text(
                        '${inc.latitud!.toStringAsFixed(5)}, '
                        '${inc.longitud!.toStringAsFixed(5)}',
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text('Evidencias', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text('${_detail!.evidencias.length} adjunto(s)'),
            ),
          ),
          if (inc.resumenIa != null && inc.resumenIa!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Análisis IA', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              color: colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      color: colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(inc.resumenIa!)),
                  ],
                ),
              ),
            ),
          ],
          if (_detail!.asignacion != null) ...[
            const SizedBox(height: 16),
            Text('Asignación', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.build_circle_outlined),
                title: Text(
                  _detail!.asignacion!['taller_nombre']?.toString() ??
                      'Taller asignado',
                ),
                subtitle: Text(
                  _detail!.asignacion!['estado']?.toString() ?? '',
                ),
              ),
            ),
          ],
          if (_detail!.ofertas.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Ofertas de talleres', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ..._detail!.ofertas.map((oferta) {
              final aceptada = oferta.estado == 'ACEPTADA';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              oferta.tallerNombre ?? 'Taller',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          Chip(label: Text(oferta.estado)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${oferta.monto.toStringAsFixed(2)} BOB', style: theme.textTheme.headlineSmall),
                      if (oferta.tiempoEstimadoMin != null)
                        Text('Tiempo estimado: ${oferta.tiempoEstimadoMin} min'),
                      if (oferta.calificacion != null)
                        Text('Calificación: ${oferta.calificacion!.toStringAsFixed(1)} / 5'),
                      if (oferta.comentarioTaller != null)
                        Text(oferta.comentarioTaller!),
                      const SizedBox(height: 12),
                      if (oferta.estado == 'PENDIENTE')
                        FilledButton(
                          onPressed: () => _seleccionarOferta(oferta),
                          child: const Text('Elegir este taller'),
                        ),
                      if (aceptada && inc.estado != 'PAGADO')
                        FilledButton(
                          onPressed: () => _pagarOferta(oferta),
                          child: const Text('Pagar servicio'),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 24),
          if (isActive && !inc.isPendingSync)
            FilledButton.icon(
              onPressed: () => context.push('/tracking/$trackId'),
              icon: const Icon(Icons.radar),
              label: const Text('Seguimiento en vivo'),
            ),
          if (inc.isCancelable && !inc.isPendingSync) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _cancelling ? null : () => _cancel(trackId),
              icon: _cancelling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cancel_outlined),
              label: const Text('Cancelar emergencia'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
            ),
          ],
          if (inc.estado == 'FINALIZADO' || inc.estado == 'PAGADO') ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _calificar,
              icon: const Icon(Icons.star_outline),
              label: const Text('Calificar servicio'),
            ),
          ],
        ],
      ),
    );
  }
}
