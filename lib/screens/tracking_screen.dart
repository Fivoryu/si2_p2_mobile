import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_errors.dart';
import '../data/models/incidente.dart';
import '../providers/app_providers.dart';
import '../services/ws_service.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key, required this.incidentId});

  final String incidentId;

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final _ws = WsService();
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _pollTimer;

  String _estado = 'PENDIENTE';
  String? _prioridad;
  String? _resumenIa;
  String? _statusMessage;
  double? _techLat;
  double? _techLng;
  String? _error;
  bool _loading = true;
  bool _wsConnected = false;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
    _connectWs();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_wsConnected) _loadSnapshot(silent: true);
    });
  }

  void _applyIncident(Incidente inc) {
    setState(() {
      _estado = inc.estado;
      _prioridad = inc.prioridad;
      _resumenIa = inc.resumenIa;
    });
  }

  void _applyWsData(String type, Map<String, dynamic>? data) {
    if (data == null) return;
    switch (type) {
      case 'STATE_SNAPSHOT':
        setState(() {
          _estado = data['estado'] as String? ?? _estado;
          _prioridad = data['prioridad'] as String?;
          _resumenIa = data['resumen_ia'] as String?;
        });
        break;
      case 'STATUS_CHANGED':
        setState(() {
          _estado = data['estado_nuevo'] as String? ?? _estado;
          _statusMessage = data['comentario'] as String?;
        });
        break;
      case 'TECH_LOCATION':
        setState(() {
          _techLat = (data['lat'] as num?)?.toDouble();
          _techLng = (data['lng'] as num?)?.toDouble();
        });
        break;
    }
  }

  Future<void> _loadSnapshot({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final detail =
          await ref.read(incidenteApiProvider).getById(widget.incidentId);
      if (mounted) {
        _applyIncident(detail.incidente);
        setState(() {
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _loading = false;
          _error = messageFromDio(e);
        });
      }
    }
  }

  Future<void> _connectWs() async {
    try {
      final auth = ref.read(authServiceProvider);
      final token = await auth.getToken();
      final tenantId = await auth.getTenantId();
      if (token == null || tenantId == null) {
        setState(() => _error = 'Sesión no válida');
        return;
      }

      final stream = _ws.connect(
        tenantId: tenantId,
        incidentId: widget.incidentId,
        token: token,
      );

      _sub = stream.listen(
        (msg) {
          final type = msg['type'] as String? ?? '';
          final data = msg['data'] as Map<String, dynamic>?;
          if (type == 'PONG') return;
          setState(() => _wsConnected = true);
          _applyWsData(type, data);
        },
        onError: (e) {
          setState(() {
            _wsConnected = false;
            if (_error == null) _error = e.toString();
          });
        },
      );
    } catch (e) {
      setState(() {
        _wsConnected = false;
        _error ??= e.toString();
      });
    }
  }

  bool get _canCancel =>
      _estado == 'PENDIENTE' || _estado == 'BUSCANDO_TALLER';

  Future<void> _cancel() async {
    final motivoCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.cancel_outlined),
        title: const Text('Cancelar emergencia'),
        content: TextField(
          controller: motivoCtrl,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar incidente'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _cancelling = true);
    try {
      await ref.read(incidenteApiProvider).cancel(
            widget.incidentId,
            motivo: motivoCtrl.text.trim().isEmpty
                ? null
                : motivoCtrl.text.trim(),
          );
      ref.invalidate(incidentesProvider);
      if (mounted) {
        setState(() {
          _estado = 'CANCELADO';
          _cancelling = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incidente cancelado')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageFromDio(e))),
        );
      }
    } finally {
      motivoCtrl.dispose();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pollTimer?.cancel();
    _ws.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento en vivo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadSnapshot(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSnapshot,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    Incidente.estadoLabel(_estado),
                                    style: theme.textTheme.titleLarge,
                                  ),
                                ),
                                if (_prioridad != null)
                                  Chip(
                                    label: Text(_prioridad!),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            if (_statusMessage != null) ...[
                              const SizedBox(height: 8),
                              Text(_statusMessage!),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              _wsConnected
                                  ? 'Conectado en tiempo real'
                                  : 'Actualización periódica',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimaryContainer
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_resumenIa != null && _resumenIa!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.psychology_outlined,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Análisis IA',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(_resumenIa!),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _techLat != null && _techLng != null
                            ? Column(
                                children: [
                                  Icon(
                                    Icons.local_shipping,
                                    size: 48,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('Ubicación del técnico'),
                                  Text(
                                    '${_techLat!.toStringAsFixed(5)}, '
                                    '${_techLng!.toStringAsFixed(5)}',
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  Icon(
                                    Icons.hourglass_empty,
                                    size: 48,
                                    color: colorScheme.outline,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Esperando ubicación del técnico…',
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Aviso: $_error',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                    if (_canCancel) ...[
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _cancelling ? null : _cancel,
                        icon: _cancelling
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cancel_outlined),
                        label: const Text('Cancelar emergencia'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () =>
                          context.push('/incident/${widget.incidentId}'),
                      child: const Text('Ver detalle completo'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
