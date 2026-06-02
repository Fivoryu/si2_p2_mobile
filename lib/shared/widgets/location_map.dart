import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Mapa OpenStreetMap con marcador en la posición del conductor.
class LocationMap extends StatelessWidget {
  const LocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 220,
    this.zoom = 15,
    this.borderRadius = 12,
  });

  final double latitude;
  final double longitude;
  final double height;
  final double zoom;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: zoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.emergencias.emergencias_mobile',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.location_on,
                    size: 44,
                    color: colorScheme.error,
                    shadows: const [
                      Shadow(blurRadius: 4, color: Colors.black26),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
