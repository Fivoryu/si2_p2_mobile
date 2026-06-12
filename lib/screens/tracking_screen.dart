import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' show LatLng, Distance, LengthUnit;

import '../core/api_errors.dart';
import '../data/models/incidente.dart';
import '../providers/app_providers.dart';
import '../services/route_animator.dart';
import '../services/ws_service.dart';
import '../utils/route_progress.dart';
import '../shared/widgets/animated_tracking_map.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key, required this.incidentId});

  final String incidentId;

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final _ws = WsService();
  final _routeAnimator = RouteAnimator();
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _pollTimer;

  String _estado = 'PENDIENTE';
  String? _prioridad;
  String? _resumenIa;
  String? _statusMessage;
  double? _techLat;
  double? _techLng;
  double? _clienteLat;
  double? _clienteLng;
  double? _techStartLat;
  double? _techStartLng;
  String? _error;
  bool _loading = true;
  bool _wsConnected = false;
  bool _cancelling = false;
  bool _seleccionandoOferta = false;
  double _progresoRuta = 0.0;
  double _distanciaRestanteKm = 0.0;
  int _tiempoRestanteMin = 0;
  double _routeTotalKm = 0;
  double _simVelocidadKmh = 40;
  double _simDuracionMin = 0;
  List<LatLng> _rutaCoords = [];
  List<OfertaTaller> _ofertas = const [];
  OfertaTaller? _ofertaAceptada;
  bool _pagoLoading = false;
  bool _calificacionLoading = false;
  String? _tenantId;

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
    _connectWs();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadSnapshot(silent: true);
    });
  }

  void _maybeStartRouteAnimation() {
    // La simulación la conduce el servidor (TECH_LOCATION / polling).
    // El marcador usa coordenadas GPS reales, no interpolación local.
  }

  void _actualizarTiemposRestantes() {
    if (_routeTotalKm <= 0) return;
    _distanciaRestanteKm = _routeTotalKm * (1 - _progresoRuta);
    if (_simDuracionMin > 0) {
      _tiempoRestanteMin = (_simDuracionMin * (1 - _progresoRuta)).ceil().clamp(0, 999);
    } else if (_simVelocidadKmh > 0) {
      _tiempoRestanteMin = (_distanciaRestanteKm / _simVelocidadKmh * 60).ceil();
    } else {
      _tiempoRestanteMin = (_distanciaRestanteKm / 40 * 60).ceil();
    }
  }

  void _syncTechPosition(double lat, double lng) {
    if (!lat.isFinite || !lng.isFinite) return;

    _techLat = lat;
    _techLng = lng;
    if (_techStartLat == null) {
      _techStartLat = lat;
      _techStartLng = lng;
    }

    final point = LatLng(lat, lng);
    final tripStart = _techStartLat != null && _techStartLng != null
        ? LatLng(_techStartLat!, _techStartLng!)
        : null;
    final tripEnd = _clienteLat != null && _clienteLng != null
        ? LatLng(_clienteLat!, _clienteLng!)
        : null;

    _progresoRuta = RouteProgress.compute(
      current: point,
      route: _rutaCoords,
      tripStart: tripStart,
      tripEnd: tripEnd,
      previous: _progresoRuta,
    );

    if (_rutaCoords.length >= 2) {
      if (_routeAnimator.route.length != _rutaCoords.length) {
        _routeAnimator.setRoute(_rutaCoords, startProgress: _progresoRuta);
      } else {
        _routeAnimator.setProgress(_progresoRuta);
      }
      _actualizarTiemposRestantes();
    } else {
      _actualizarProgreso();
    }
  }

  void _applyUltimaUbicacion(Map<String, dynamic>? ubicacion) {
    if (ubicacion == null) return;
    final lat = (ubicacion['latitud'] as num?)?.toDouble();
    final lng = (ubicacion['longitud'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    _syncTechPosition(lat, lng);
  }

  void _applyRoutePolyline(Map<String, dynamic>? data, {bool animate = false}) {
    if (data == null) return;
    final raw = data['coords'] as List<dynamic>? ?? [];
    if (raw.isEmpty) return;

    final simActiva = data['simulacion_activa'] == true;

    final coords = raw
        .map((c) {
          final m = c as Map<String, dynamic>;
          return LatLng(
            (m['lat'] as num).toDouble(),
            (m['lng'] as num).toDouble(),
          );
        })
        .toList(growable: false);

    if (!simActiva && _rutaCoords.isNotEmpty) return;

    _rutaCoords = coords;
    _routeTotalKm = (data['distancia_km'] as num?)?.toDouble() ?? _calcRouteLengthKm(coords);

    final velSim = (data['velocidad_sim_kmh'] as num?)?.toDouble();
    if (velSim != null && velSim > 0) _simVelocidadKmh = velSim;

    final durSeg = (data['duracion_sim_seg'] as num?) ??
        (data['duracion_est_seg'] as num?);
    if (durSeg != null && durSeg > 0) {
      _simDuracionMin = durSeg / 60.0;
    }

    final startProgress = _techLat != null && _techLng != null
        ? RouteProgress.compute(
            current: LatLng(_techLat!, _techLng!),
            route: coords,
            tripStart: _techStartLat != null && _techStartLng != null
                ? LatLng(_techStartLat!, _techStartLng!)
                : coords.first,
            tripEnd: _clienteLat != null && _clienteLng != null
                ? LatLng(_clienteLat!, _clienteLng!)
                : coords.last,
            previous: _progresoRuta,
          )
        : _progresoRuta;
    _routeAnimator.setRoute(coords, startProgress: startProgress);
    _progresoRuta = startProgress;

    if (_techLat != null && _techLng != null) {
      _syncTechPosition(_techLat!, _techLng!);
    }
  }

  double _calcRouteLengthKm(List<LatLng> coords) {
    if (coords.length < 2) return 0;
    const dist = Distance();
    var total = 0.0;
    for (var i = 0; i < coords.length - 1; i++) {
      total += dist.as(LengthUnit.Kilometer, coords[i], coords[i + 1]);
    }
    return total;
  }

  Future<void> _loadRouteIfNeeded() async {
    if (_rutaCoords.isNotEmpty) return;
    if (_estado != 'EN_CAMINO' && _estado != 'TALLER_ASIGNADO') return;
    if (_clienteLat == null || _techLat == null) return;

    try {
      final data = await ref.read(incidenteApiProvider).getRuta(widget.incidentId);
      if (mounted) {
        setState(() => _applyRoutePolyline(data, animate: false));
      }
    } catch (_) {
      // sin ruta disponible aún
    }
  }

  Future<void> _cargarOfertaAceptada() async {
    try {
      final detail = await ref.read(incidenteApiProvider).getById(widget.incidentId);
      final aceptada = detail.ofertas.firstWhere(
        (o) => o.estado == 'ACEPTADA',
        orElse: () => OfertaTaller(id: '', tallerId: '', monto: 0, estado: ''),
      );
      if (mounted) {
        setState(() => _ofertaAceptada = aceptada.id.isNotEmpty ? aceptada : null);
      }
    } catch (_) {}
  }

  Future<void> _pagarOferta(OfertaTaller oferta) async {
    setState(() => _pagoLoading = true);
    try {
      await ref.read(incidenteApiProvider).pagarMock(
        incidenteId: widget.incidentId,
        cotizacionId: oferta.id,
      );
      await ref.read(incidenteApiProvider).getById(widget.incidentId);
      if (mounted) {
        setState(() {
          _estado = 'PAGADO';
          _pagoLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pago registrado exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _pagoLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al pagar: ${messageFromDio(e)}')),
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

    setState(() => _calificacionLoading = true);
    try {
      await ref.read(incidenteApiProvider).calificar(
        widget.incidentId,
        estrellas,
        comentario: comentarioCtrl.text.trim().isEmpty ? null : comentarioCtrl.text.trim(),
      );
      if (mounted) {
        setState(() => _calificacionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calificación enviada')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _calificacionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${messageFromDio(e)}')),
        );
      }
    } finally {
      comentarioCtrl.dispose();
    }
  }

  void _applyDetail(IncidenteDetail detail) {
    final inc = detail.incidente;
    setState(() {
      _estado = inc.estado;
      _prioridad = inc.prioridad;
      _resumenIa = inc.resumenIa;
      _clienteLat = inc.latitud;
      _clienteLng = inc.longitud;
      _ofertas = detail.ofertas
          .where((o) => o.estado == 'PENDIENTE')
          .toList(growable: false);
      if (inc.estado == 'FINALIZADO' || inc.estado == 'PAGADO') {
        final aceptada = detail.ofertas.firstWhere(
          (o) => o.estado == 'ACEPTADA',
          orElse: () => OfertaTaller(id: '', tallerId: '', monto: 0, estado: ''),
        );
        _ofertaAceptada = aceptada.id.isNotEmpty ? aceptada : null;
      }
      _applyUltimaUbicacion(detail.ultimaUbicacion);
    });
  }

  void _applyWsData(String type, Map<String, dynamic>? data) {
    if (data == null) return;
    switch (type) {
      case 'STATE_SNAPSHOT':
        final incidente = data['incidente'] as Map<String, dynamic>?;
        final ultima = data['ultima_ubicacion'] as Map<String, dynamic>?;
        setState(() {
          if (incidente != null) {
            _estado = incidente['estado'] as String? ?? _estado;
            _prioridad = incidente['prioridad'] as String?;
            _resumenIa = incidente['resumen_ia'] as String?;
            _clienteLat =
                (incidente['latitud'] as num?)?.toDouble() ?? _clienteLat;
            _clienteLng =
                (incidente['longitud'] as num?)?.toDouble() ?? _clienteLng;
          }
          _applyUltimaUbicacion(ultima);
        });
        break;
      case 'STATUS_CHANGED':
        final nuevo = data['estado_nuevo'] as String? ?? _estado;
        setState(() {
          _estado = nuevo;
          _statusMessage = data['comentario'] as String?;
          if (_estado == 'EN_ATENCION') {
            _routeAnimator.stop();
            _progresoRuta = 1.0;
            _distanciaRestanteKm = 0;
            _tiempoRestanteMin = 0;
          }
        });
        _maybeStartRouteAnimation();
        ref.invalidate(incidentesProvider);
        if (_estado == 'FINALIZADO') {
          _cargarOfertaAceptada();
        }
        break;
      case 'TECH_LOCATION':
        setState(() {
          final lat = (data['lat'] as num?)?.toDouble();
          final lng = (data['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            _syncTechPosition(lat, lng);
          }
        });
        break;
      case 'ROUTE_POLYLINE':
        setState(() => _applyRoutePolyline(data, animate: true));
        _maybeStartRouteAnimation();
        break;
      case 'SIMULATION_ENDED':
        _routeAnimator.stop();
        break;
      case 'TECH_ARRIVED':
        _routeAnimator.stop();
        setState(() {
          _estado = 'EN_ATENCION';
          final lat = (data['lat'] as num?)?.toDouble();
          final lng = (data['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            _syncTechPosition(lat, lng);
          }
          _progresoRuta = 1.0;
          _distanciaRestanteKm = 0;
          _tiempoRestanteMin = 0;
        });
        break;
      case 'OFFER_RECEIVED':
      case 'OFFERS_AVAILABLE':
        _loadSnapshot(silent: true);
        break;
    }
  }

  void _actualizarProgreso() {
    if (_techLat == null || _techLng == null || _clienteLat == null || _clienteLng == null) {
      return;
    }
    const distancia = Distance();
    final clientePos = LatLng(_clienteLat!, _clienteLng!);
    final current = LatLng(_techLat!, _techLng!);
    final restante = distancia.as(LengthUnit.Kilometer, current, clientePos);
    _distanciaRestanteKm = restante;
    _tiempoRestanteMin = (restante / 40 * 60).ceil();

    final tripStart = _techStartLat != null && _techStartLng != null
        ? LatLng(_techStartLat!, _techStartLng!)
        : current;
    _progresoRuta = RouteProgress.compute(
      current: current,
      route: _rutaCoords,
      tripStart: tripStart,
      tripEnd: clientePos,
      previous: _progresoRuta,
    );
  }

  Future<void> _loadSnapshot({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final detail =
          await ref.read(incidenteApiProvider).getById(widget.incidentId);
      if (mounted) {
        _applyDetail(detail);
        await _loadRouteIfNeeded();
        _maybeStartRouteAnimation();
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
      _tenantId = tenantId;

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
            _error ??= e.toString();
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
      _estado == 'PENDIENTE' || _estado == 'BUSCANDO_TALLER' || _estado == 'TALLER_ASIGNADO';

  bool get _puedeElegirOferta =>
      _estado == 'BUSCANDO_TALLER' && _ofertas.isNotEmpty;

  Future<void> _seleccionarOferta(OfertaTaller oferta) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.local_offer_outlined),
        title: const Text('Aceptar oferta'),
        content: Text(
          '¿Confirmar la oferta de ${oferta.tallerNombre ?? 'taller'} '
          'por ${oferta.monto.toStringAsFixed(2)} BOB?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _seleccionandoOferta = true);
    try {
      await ref.read(incidenteApiProvider).seleccionarOferta(oferta.id);
      ref.invalidate(incidentesProvider);
      await _loadSnapshot(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oferta aceptada. El técnico va en camino.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageFromDio(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _seleccionandoOferta = false);
    }
  }

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
        context.pop();
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

  bool get _mostrarMapa =>
      _clienteLat != null &&
      _clienteLng != null &&
      _clienteLat!.isFinite &&
      _clienteLng!.isFinite &&
      _estado != 'CANCELADO';

  Widget _buildMapaEnVivo(BuildContext context) {
    final mapHeight = MediaQuery.sizeOf(context).height * 0.42;
    return AnimatedTrackingMap(
      clienteLatLng: LatLng(_clienteLat!, _clienteLng!),
      clienteLabel: 'Tú',
      tecnicoLatLng: _techLat != null && _techLng != null
          ? LatLng(_techLat!, _techLng!)
          : null,
      rutaCoords: _rutaCoords,
      progresoRuta: _progresoRuta,
      distanciaRestanteKm: _distanciaRestanteKm,
      tiempoRestanteMin: _tiempoRestanteMin,
      altura: mapHeight.clamp(280, 480),
      autoFit: true,
      followTecnico: false,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pollTimer?.cancel();
    _routeAnimator.dispose();
    _ws.close(tenantId: _tenantId, incidentId: widget.incidentId);
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
                    if (_mostrarMapa) ...[
                      const SizedBox(height: 16),
                      _buildMapaEnVivo(context),
                    ],
                    if (_puedeElegirOferta) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.local_offer,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Ofertas de talleres (${_ofertas.length})',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Elija la oferta que prefiera para continuar.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ..._ofertas.map((oferta) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    tileColor: colorScheme.surfaceContainerHighest,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: colorScheme.primaryContainer,
                                      child: Icon(
                                        Icons.build_circle_outlined,
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                    title: Text(
                                      oferta.tallerNombre ?? 'Taller',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${oferta.monto.toStringAsFixed(2)} BOB'
                                          '${oferta.tiempoEstimadoMin != null ? ' · ~${oferta.tiempoEstimadoMin} min' : ''}',
                                        ),
                                        if (oferta.calificacion != null)
                                          Text(
                                            '★ ${oferta.calificacion!.toStringAsFixed(1)}',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        if (oferta.comentarioTaller != null &&
                                            oferta.comentarioTaller!.isNotEmpty)
                                          Text(
                                            oferta.comentarioTaller!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                    trailing: _seleccionandoOferta
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : FilledButton(
                                            onPressed: _seleccionandoOferta
                                                ? null
                                                : () =>
                                                    _seleccionarOferta(oferta),
                                            child: const Text('Elegir'),
                                          ),
                                    isThreeLine: true,
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_estado == 'FINALIZADO' && _ofertaAceptada != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: colorScheme.tertiaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.receipt_long, color: colorScheme.onTertiaryContainer),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Servicio finalizado',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: colorScheme.onTertiaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_ofertaAceptada!.tallerNombre ?? "Taller"}'
                                ' — ${_ofertaAceptada!.monto.toStringAsFixed(2)} BOB',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _pagoLoading ? null : () => _pagarOferta(_ofertaAceptada!),
                                icon: _pagoLoading
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.payment),
                                label: Text(_pagoLoading ? 'Procesando...' : 'Pagar servicio'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_estado == 'PAGADO') ...[
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.check_circle, color: colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text('Pago completado', style: theme.textTheme.titleMedium),
                                ],
                              ),
                              const SizedBox(height: 12),
                              FilledButton.tonalIcon(
                                onPressed: _calificacionLoading ? null : _calificar,
                                icon: _calificacionLoading
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.star_outline),
                                label: Text(_calificacionLoading ? 'Enviando...' : 'Calificar servicio'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                  ],
                ),
              ),
            ),
    );
  }
}
