import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  bool _usarFakeGps = false;
  double _fakeLat = -17.7833;
  double _fakeLng = -63.1821;

  bool get usarFakeGps => _usarFakeGps;

  void setUsarFakeGps(bool valor) {
    _usarFakeGps = valor;
  }

  void setFakeCoords(double lat, double lng) {
    _fakeLat = lat;
    _fakeLng = lng;
  }

  double get fakeLat => _fakeLat;
  double get fakeLng => _fakeLng;

  Future<Position> current() async {
    if (_usarFakeGps) {
      return Position(
        latitude: _fakeLat,
        longitude: _fakeLng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('GPS desactivado');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicación denegado');
    }

    final lastKnown = await Geolocator.getLastKnownPosition();
    final recentLast = lastKnown != null &&
        DateTime.now().difference(lastKnown.timestamp).inMinutes < 10;

    if (recentLast) {
      return lastKnown;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      if (lastKnown != null) return lastKnown;
      rethrow;
    }
  }

  static Future<String> addressFromPosition(Position pos) async {
    return '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
  }
}