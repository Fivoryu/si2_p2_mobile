import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  String _estado = 'PENDIENTE';
  String? _statusMessage;
  double? _techLat;
  double? _techLng;
  String? _error;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
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
        (data) {
          final type = data['type'] as String? ?? '';
          switch (type) {
            case 'STATE_SNAPSHOT':
            case 'STATUS_CHANGED':
              setState(() {
                _estado = data['estado'] as String? ?? _estado;
                _statusMessage = data['comentario'] as String?;
              });
              break;
            case 'TECH_LOCATION':
              setState(() {
                _techLat = (data['latitud'] as num?)?.toDouble();
                _techLng = (data['longitud'] as num?)?.toDouble();
              });
              break;
            case 'PONG':
              break;
          }
        },
        onError: (e) => setState(() => _error = e.toString()),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ws.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seguimiento en vivo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estado: $_estado',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(_statusMessage!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Center(
                  child: _error != null
                      ? Text('Error WS: $_error')
                      : _techLat != null && _techLng != null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.local_shipping, size: 64),
                                const SizedBox(height: 12),
                                const Text('Ubicación del técnico'),
                                Text(
                                  '${_techLat!.toStringAsFixed(5)}, '
                                  '${_techLng!.toStringAsFixed(5)}',
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(
                                  'Esperando ubicación del técnico…',
                                  style:
                                      Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Incidente: ${widget.incidentId}',
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
