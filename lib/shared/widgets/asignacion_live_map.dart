import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../providers/app_providers.dart';
import '../../services/location_service.dart';
import '../../utils/route_progress.dart';
import 'animated_tracking_map.dart';

/// Mapa en vivo para la vista del técnico (ruta + cliente + ubicación propia).
class AsignacionLiveMap extends ConsumerStatefulWidget {
  const AsignacionLiveMap({
    super.key,
    required this.incidenteId,
    required this.clienteLat,
    required this.clienteLng,
  });

  final String incidenteId;
  final double clienteLat;
  final double clienteLng;

  @override
  ConsumerState<AsignacionLiveMap> createState() => _AsignacionLiveMapState();
}

class _AsignacionLiveMapState extends ConsumerState<AsignacionLiveMap> {
  Timer? _pollTimer;
  List<LatLng> _rutaCoords = [];
  double? _techLat;
  double? _techLng;
  double? _tripStartLat;
  double? _tripStartLng;
  double _progreso = 0;
  double _distKm = 0;
  int _tiempoMin = 0;
  double _routeTotalKm = 0;
  double _simVelocidadKmh = 40;

  @override
  void initState() {
    super.initState();
    _refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    try {
      final data = await ref.read(incidenteApiProvider).getRuta(widget.incidenteId);
      final raw = data['coords'] as List<dynamic>? ?? [];
      if (raw.isEmpty) return;
      final coords = raw
          .map((c) {
            final m = c as Map<String, dynamic>;
            return LatLng(
              (m['lat'] as num).toDouble(),
              (m['lng'] as num).toDouble(),
            );
          })
          .toList(growable: false);
      if (coords.isNotEmpty) {
        _tripStartLat = coords.first.latitude;
        _tripStartLng = coords.first.longitude;
      }
      _rutaCoords = coords;
      _routeTotalKm = (data['distancia_km'] as num?)?.toDouble() ?? 0;
      final vel = (data['velocidad_sim_kmh'] as num?)?.toDouble();
      if (vel != null && vel > 0) _simVelocidadKmh = vel;
    } catch (_) {}
  }

  Future<void> _refresh() async {
    try {
      await _loadRoute();
      final api = ref.read(incidenteApiProvider);
      final detail = await api.getById(widget.incidenteId);

      double? lat = (detail.ultimaUbicacion?['latitud'] as num?)?.toDouble();
      double? lng = (detail.ultimaUbicacion?['longitud'] as num?)?.toDouble();

      if (lat == null || lng == null) {
        final pos = await LocationService().current();
        lat = pos.latitude;
        lng = pos.longitude;
      }

      if (!mounted) return;

      _tripStartLat ??= lat;
      _tripStartLng ??= lng;

      final tripStart = LatLng(_tripStartLat!, _tripStartLng!);
      final tripEnd = LatLng(widget.clienteLat, widget.clienteLng);
      final progreso = RouteProgress.compute(
        current: LatLng(lat, lng),
        route: _rutaCoords,
        tripStart: tripStart,
        tripEnd: tripEnd,
        previous: _progreso,
      );

      final distKm = _routeTotalKm > 0
          ? _routeTotalKm * (1 - progreso)
          : const Distance().as(
              LengthUnit.Kilometer,
              LatLng(lat, lng),
              tripEnd,
            );

      setState(() {
        _techLat = lat;
        _techLng = lng;
        _progreso = progreso;
        _distKm = distKm;
        _tiempoMin = _simVelocidadKmh > 0
            ? (distKm / _simVelocidadKmh * 60).ceil()
            : (distKm / 40 * 60).ceil();
      });
    } catch (_) {}
  }

  void resetRoute() {
    _rutaCoords = [];
    _progreso = 0;
    _tripStartLat = null;
    _tripStartLng = null;
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mapa en vivo', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        AnimatedTrackingMap(
          clienteLatLng: LatLng(widget.clienteLat, widget.clienteLng),
          clienteLabel: 'Cliente',
          tecnicoLabel: 'Tú',
          tecnicoLatLng: _techLat != null && _techLng != null
              ? LatLng(_techLat!, _techLng!)
              : null,
          rutaCoords: _rutaCoords,
          progresoRuta: _progreso,
          distanciaRestanteKm: _distKm,
          tiempoRestanteMin: _tiempoMin,
          altura: 280,
          autoFit: true,
          followTecnico: false,
        ),
      ],
    );
  }
}
