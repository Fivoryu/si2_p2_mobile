import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AnimatedTrackingMap extends StatefulWidget {
  const AnimatedTrackingMap({
    super.key,
    required this.clienteLatLng,
    this.tecnicoLatLng,
    this.rutaCoords = const [],
    this.progresoRuta = 0.0,
    this.distanciaRestanteKm = 0.0,
    this.tiempoRestanteMin = 0,
    this.altura = 300,
    this.zoom = 14,
    this.showTiles = true,
    this.clienteLabel = 'Cliente',
    this.tecnicoLabel = 'Técnico',
    this.autoFit = true,
    this.followTecnico = false,
  });

  final LatLng clienteLatLng;
  final LatLng? tecnicoLatLng;
  final List<LatLng> rutaCoords;
  final double progresoRuta;
  final double distanciaRestanteKm;
  final int tiempoRestanteMin;
  final double altura;
  final double zoom;
  final bool showTiles;
  final String clienteLabel;
  final String tecnicoLabel;
  final bool autoFit;
  final bool followTecnico;

  @override
  State<AnimatedTrackingMap> createState() => _AnimatedTrackingMapState();
}

class _AnimatedTrackingMapState extends State<AnimatedTrackingMap>
    with TickerProviderStateMixin {
  static const _speedMs = 11.11; // ~40 km/h

  final _mapController = MapController();
  late AnimationController _pulseController;
  late AnimationController _moveController;
  late Animation<double> _moveAnimation;
  late Animation<double> _pulseAnimation;

  LatLng? _displayTecnico;
  LatLng? _moveFrom;
  LatLng? _moveTo;
  double _maxRouteProgress = 0;
  bool _didInitialFit = false;
  bool _userMovedMap = false;

  static bool _valid(LatLng? p) =>
      p != null && p.latitude.isFinite && p.longitude.isFinite;

  static List<LatLng> _finite(Iterable<LatLng> points) =>
      points.where((p) => p.latitude.isFinite && p.longitude.isFinite).toList();

  @override
  void initState() {
    super.initState();
    _displayTecnico = widget.tecnicoLatLng;
    if (_displayTecnico != null) {
      _maxRouteProgress = _progressAlongRoute(_displayTecnico!);
    }
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _moveController = AnimationController(vsync: this);
    _moveAnimation = CurvedAnimation(parent: _moveController, curve: Curves.linear);
    _moveController.addListener(_onMoveTick);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToContent(force: true));
  }

  double _progressAlongRoute(LatLng point) {
    final ruta = widget.rutaCoords;
    if (ruta.length < 2) return 0;

    const dist = Distance();
    final total = _routeLengthKm(ruta);
    if (total <= 0) return 0;

    var bestDist = double.infinity;
    var bestWalked = 0.0;
    var walked = 0.0;

    for (var i = 0; i < ruta.length - 1; i++) {
      final a = ruta[i];
      final b = ruta[i + 1];
      final segKm = dist.as(LengthUnit.Kilometer, a, b);
      if (segKm <= 0) continue;

      final t = _projectOnSegment(a, b, point);
      final proj = LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
      final d = dist.as(LengthUnit.Kilometer, point, proj);
      if (d < bestDist) {
        bestDist = d;
        bestWalked = walked + segKm * t;
      }
      walked += segKm;
    }
    return (bestWalked / total).clamp(0.0, 1.0);
  }

  double _projectOnSegment(LatLng a, LatLng b, LatLng p) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) return 0;
    final t = ((p.longitude - a.longitude) * dx + (p.latitude - a.latitude) * dy) / len2;
    return t.clamp(0.0, 1.0);
  }

  double _routeLengthKm(List<LatLng> ruta) {
    if (ruta.length < 2) return 0;
    const dist = Distance();
    var total = 0.0;
    for (var i = 0; i < ruta.length - 1; i++) {
      total += dist.as(LengthUnit.Kilometer, ruta[i], ruta[i + 1]);
    }
    return total;
  }

  bool _isForward(LatLng next) {
    if (_displayTecnico == null) return true;
    const dist = Distance();
    final gapM = dist.as(LengthUnit.Meter, _displayTecnico!, next);
    if (gapM < 0.3) return false;

    if (widget.rutaCoords.length > 1) {
      final nextProg = _progressAlongRoute(next);
      if (nextProg < _maxRouteProgress - 0.002) return false;
      _maxRouteProgress = math.max(_maxRouteProgress, nextProg);
      return true;
    }

    // Sin ruta: aceptar solo si se aleja del punto anterior (evita jitter).
    return gapM >= 0.5;
  }

  void _animateTo(LatLng next) {
    if (!_valid(next)) return;
    if (!_isForward(next)) return;

    final from = _moveController.isAnimating
        ? (_valid(_displayTecnico) ? _displayTecnico! : next)
        : (_valid(_displayTecnico) ? _displayTecnico! : next);
    const dist = Distance();
    final meters = dist.as(LengthUnit.Meter, from, next);
    if (meters < 0.3) return;

    final ms = (meters / _speedMs * 1000).clamp(400, 1100).round();

    _moveFrom = from;
    _moveTo = next;
    _moveController
      ..duration = Duration(milliseconds: ms)
      ..forward(from: 0);
  }

  List<LatLng> _contentPoints(LatLng? tecnico) {
    final points = <LatLng>[widget.clienteLatLng];
    if (tecnico != null) points.add(tecnico);
    if (widget.rutaCoords.isNotEmpty) points.addAll(widget.rutaCoords);
    return points;
  }

  void _fitToContent({bool force = false}) {
    if (!widget.autoFit) return;
    if (!mounted) return;
    if (!_valid(widget.clienteLatLng)) return;

    final tecnico = _valid(_displayTecnico)
        ? _displayTecnico
        : (_valid(widget.tecnicoLatLng) ? widget.tecnicoLatLng : null);
    final points = _finite(_contentPoints(tecnico));
    if (points.isEmpty) return;

    try {
      if (points.length >= 2) {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: points,
            padding: const EdgeInsets.all(56),
            maxZoom: 16,
          ),
        );
      } else {
        _mapController.move(points.first, widget.zoom);
      }
      _didInitialFit = true;
      _userMovedMap = false;
    } catch (_) {
      try {
        _mapController.move(widget.clienteLatLng, widget.zoom);
      } catch (_) {}
    }
  }

  void _onMoveTick() {
    if (_moveFrom == null || _moveTo == null) return;
    if (!_valid(_moveFrom) || !_valid(_moveTo)) return;
    final t = _moveAnimation.value;
    if (!t.isFinite) return;
    final lat = _moveFrom!.latitude + (_moveTo!.latitude - _moveFrom!.latitude) * t;
    final lng = _moveFrom!.longitude + (_moveTo!.longitude - _moveFrom!.longitude) * t;
    if (!lat.isFinite || !lng.isFinite) return;
    setState(() => _displayTecnico = LatLng(lat, lng));
  }

  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      _userMovedMap = true;
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.tecnicoLatLng;
    if (!_valid(next)) return;

    if (oldWidget.rutaCoords.length != widget.rutaCoords.length) {
      if (_valid(_displayTecnico ?? next)) {
        _maxRouteProgress = _progressAlongRoute(_displayTecnico ?? next!);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToContent(force: true));
    } else if (!_didInitialFit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToContent(force: true));
    }

    _animateTo(next!);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _moveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final cliente = widget.clienteLatLng;
    final tecnico = _valid(_displayTecnico)
        ? _displayTecnico
        : (_valid(widget.tecnicoLatLng) ? widget.tecnicoLatLng : null);
    final ruta = widget.rutaCoords;
    final centro = tecnico ?? cliente;
    final progreso = widget.progresoRuta.isFinite
        ? widget.progresoRuta.clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: widget.altura,
            width: double.infinity,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: centro,
                    initialZoom: widget.zoom,
                    onPositionChanged: (pos, hasGesture) => _onMapMoved(pos, hasGesture),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    if (widget.showTiles)
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.emergencias.emergencias_mobile',
                      ),
                    if (ruta.length > 1)
                      PolylineLayer(
                        polylines: [
                          if (progreso > 0.01)
                            Polyline(
                              points: ruta.sublist(
                                0,
                                (ruta.length * progreso).clamp(1, ruta.length).toInt(),
                              ),
                              strokeWidth: 6,
                              color: colorScheme.tertiary.withValues(alpha: 0.9),
                            ),
                          Polyline(
                            points: ruta,
                            strokeWidth: 5,
                            color: colorScheme.primary.withValues(alpha: 0.75),
                          ),
                          Polyline(
                            points: ruta,
                            strokeWidth: 2,
                            color: colorScheme.primary.withValues(alpha: 0.35),
                            borderStrokeWidth: 0,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: cliente,
                          width: 50,
                          height: 50,
                          child: _buildClienteMarker(colorScheme),
                        ),
                        if (tecnico != null)
                          Marker(
                            point: tecnico,
                            width: 50,
                            height: 50,
                            child: _buildTecnicoMarker(colorScheme, _pulseAnimation),
                          ),
                      ],
                    ),
                  ],
                ),
                if (_userMovedMap)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(24),
                      color: colorScheme.surface,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => _fitToContent(force: true),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.my_location, size: 18, color: colorScheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                'Ver ruta',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (tecnico != null)
          _buildInfoPanel(colorScheme, progreso)
        else
          _buildEsperandoPanel(colorScheme),
      ],
    );
  }

  Widget _buildClienteMarker(ColorScheme colorScheme) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.error.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
        ),
        Icon(
          Icons.location_on,
          size: 40,
          color: colorScheme.error,
          shadows: const [
            Shadow(blurRadius: 4, color: Colors.black26),
          ],
        ),
        Positioned(
          bottom: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: colorScheme.error,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              ' ${widget.clienteLabel}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTecnicoMarker(ColorScheme colorScheme, Animation<double> pulseAnim) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (context, child) {
        final scale = pulseAnim.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
            ),
            Icon(
              Icons.local_shipping,
              size: 32,
              color: colorScheme.primary,
              shadows: const [
                Shadow(blurRadius: 4, color: Colors.black26),
              ],
            ),
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.tecnicoLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoPanel(ColorScheme colorScheme, double progreso) {
    final dist = widget.distanciaRestanteKm;
    final tiempo = widget.tiempoRestanteMin;

    String distTxt;
    if (dist < 1) {
      distTxt = '${(dist * 1000).toInt()} m';
    } else {
      distTxt = '${dist.toStringAsFixed(1)} km';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildInfoItem(Icons.straighten, distTxt, 'Distancia', colorScheme),
          Container(
            width: 1,
            height: 30,
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
          _buildInfoItem(Icons.access_time, '$tiempo min', 'Tiempo est.', colorScheme),
          Container(
            width: 1,
            height: 30,
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
          _buildInfoItem(
            Icons.directions_car,
            '${(progreso * 100).round()}%',
            'Avance',
            colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    IconData icon,
    String valor,
    String label,
    ColorScheme colorScheme,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              valor,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildEsperandoPanel(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Esperando ubicación del técnico...',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
