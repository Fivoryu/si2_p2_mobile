import 'dart:async';

import 'package:latlong2/latlong.dart';

/// Anima suavemente un marcador a lo largo de una polilínea de ruta.
class RouteAnimator {
  List<LatLng> _route = const [];
  double _progress = 0;
  Timer? _timer;
  void Function(LatLng position, double progress)? onUpdate;

  List<LatLng> get route => _route;
  double get progress => _progress;
  bool get isRunning => _timer != null;

  void setRoute(List<LatLng> route, {double startProgress = 0}) {
    _route = route;
    _progress = startProgress.clamp(0.0, 1.0);
    if (_route.isNotEmpty) {
      onUpdate?.call(positionAt(_progress), _progress);
    }
  }

  void setProgress(double value) {
    _progress = value.clamp(0.0, 1.0);
    onUpdate?.call(positionAt(_progress), _progress);
  }

  /// Progreso 0–1 sobre la polilínea para una coordenada dada.
  double progressFor(LatLng target) => _progressAtPoint(target);

  /// Avanza solo hacia adelante según la posición del servidor.
  void advanceTo(LatLng target) {
    if (_route.length < 2) return;
    final targetProgress = _progressAtPoint(target);
    if (targetProgress > _progress + 0.0001) {
      _progress = targetProgress;
    }
  }

  void start({double speedKmh = 40, Duration tick = const Duration(milliseconds: 50)}) {
    _timer?.cancel();
    if (_route.length < 2) return;

    _timer = Timer.periodic(tick, (_) {
      final totalKm = _routeLengthKm();
      if (totalKm <= 0) return;

      final kmPerTick = speedKmh / 3600 * tick.inMilliseconds / 1000;
      _progress = (_progress + kmPerTick / totalKm).clamp(0.0, 1.0);
      onUpdate?.call(positionAt(_progress), _progress);

      if (_progress >= 1.0) {
        stop();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();

  LatLng positionAt(double fraction) {
    if (_route.isEmpty) return const LatLng(0, 0);
    if (_route.length == 1) return _route.first;

    final totalKm = _routeLengthKm();
    if (totalKm <= 0) return _route.first;

    final targetKm = totalKm * fraction.clamp(0.0, 1.0);
    var walked = 0.0;
    const dist = Distance();

    for (var i = 0; i < _route.length - 1; i++) {
      final segKm = dist.as(LengthUnit.Kilometer, _route[i], _route[i + 1]);
      if (walked + segKm >= targetKm) {
        final t = segKm > 0 ? (targetKm - walked) / segKm : 0.0;
        final a = _route[i];
        final b = _route[i + 1];
        return LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
      }
      walked += segKm;
    }
    return _route.last;
  }

  double _progressAtPoint(LatLng target) {
    if (_route.length < 2) return 0;

    const dist = Distance();
    final totalKm = _routeLengthKm();
    if (totalKm <= 0) return 0;

    var bestDist = double.infinity;
    var bestWalked = 0.0;
    var walked = 0.0;

    for (var i = 0; i < _route.length - 1; i++) {
      final a = _route[i];
      final b = _route[i + 1];
      final segKm = dist.as(LengthUnit.Kilometer, a, b);
      if (segKm <= 0) continue;

      final t = _projectOnSegment(a, b, target);
      final proj = LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
      final d = dist.as(LengthUnit.Kilometer, target, proj);
      if (d < bestDist) {
        bestDist = d;
        bestWalked = walked + segKm * t;
      }
      walked += segKm;
    }

    return (bestWalked / totalKm).clamp(0.0, 1.0);
  }

  double _projectOnSegment(LatLng a, LatLng b, LatLng p) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) return 0;
    final t = ((p.longitude - a.longitude) * dx + (p.latitude - a.latitude) * dy) / len2;
    return t.clamp(0.0, 1.0);
  }

  double _routeLengthKm() {
    if (_route.length < 2) return 0;
    const dist = Distance();
    var total = 0.0;
    for (var i = 0; i < _route.length - 1; i++) {
      total += dist.as(LengthUnit.Kilometer, _route[i], _route[i + 1]);
    }
    return total;
  }
}
