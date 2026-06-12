import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Vista de ubicación: mapa OSM en línea o vista estática sin red.
class LocationMap extends StatelessWidget {
  const LocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 220,
    this.zoom = 15,
    this.borderRadius = 12,
    this.offline = false,
  });

  final double latitude;
  final double longitude;
  final double height;
  final double zoom;
  final double borderRadius;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    if (offline) {
      return _OfflineLocationPreview(
        latitude: latitude,
        longitude: longitude,
        height: height,
        borderRadius: borderRadius,
      );
    }

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

class _OfflineLocationPreview extends StatelessWidget {
  const _OfflineLocationPreview({
    required this.latitude,
    required this.longitude,
    required this.height,
    required this.borderRadius,
  });

  final double latitude;
  final double longitude;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: ColoredBox(
          color: colorScheme.surfaceContainerHighest,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: _GridPainter(color: colorScheme.outlineVariant),
              ),
              Icon(
                Icons.location_on,
                size: 48,
                color: colorScheme.error,
                shadows: const [
                  Shadow(blurRadius: 4, color: Colors.black26),
                ],
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.wifi_off,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Sin conexión — GPS guardado',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    const step = 28.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
