import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<Position> current() async {
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

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  static Future<String> addressFromPosition(Position pos) async {
    return '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
  }
}
