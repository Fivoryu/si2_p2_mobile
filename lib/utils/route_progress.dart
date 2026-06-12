import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Progreso 0–1 del recorrido (polilínea + fallback haversine).
class RouteProgress {
  RouteProgress._();

  static double onPolyline(List<LatLng> route, LatLng point) {
    if (route.length < 2) return 0;

    const dist = Distance();
    var total = 0.0;
    var walked = 0.0;
    var best = 0.0;
    var bestD = double.infinity;

    for (var i = 0; i < route.length - 1; i++) {
      final a = route[i];
      final b = route[i + 1];
      final segKm = dist.as(LengthUnit.Kilometer, a, b);
      if (segKm <= 0) continue;
      total += segKm;

      final t = _projectOnSegment(a, b, point);
      final proj = LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
      final d = dist.as(LengthUnit.Kilometer, point, proj);
      if (d < bestD) {
        bestD = d;
        best = walked + segKm * t;
      }
      walked += segKm;
    }

    if (total <= 0) return 0;
    return (best / total).clamp(0.0, 1.0);
  }

  static double haversineProgress(LatLng start, LatLng end, LatLng current) {
    const dist = Distance();
    final total = dist.as(LengthUnit.Kilometer, start, end);
    if (total <= 0) return 0;
    final fromStart = dist.as(LengthUnit.Kilometer, start, current);
    return (fromStart / total).clamp(0.0, 1.0);
  }

  static double compute({
    required LatLng current,
    List<LatLng> route = const [],
    LatLng? tripStart,
    LatLng? tripEnd,
    double previous = 0,
  }) {
    var p = previous;

    if (route.length >= 2) {
      p = math.max(p, onPolyline(route, current));
    }

    final start = tripStart ?? (route.isNotEmpty ? route.first : null);
    final end = tripEnd ?? (route.isNotEmpty ? route.last : null);
    if (start != null && end != null) {
      p = math.max(p, haversineProgress(start, end, current));
    }

    return p.clamp(0.0, 1.0);
  }

  static double _projectOnSegment(LatLng a, LatLng b, LatLng p) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) return 0;
    final t = ((p.longitude - a.longitude) * dx + (p.latitude - a.latitude) * dy) / len2;
    return t.clamp(0.0, 1.0);
  }
}
