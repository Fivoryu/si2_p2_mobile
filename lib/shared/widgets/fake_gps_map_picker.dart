import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Mapa para elegir la ubicación del GPS simulado (toque en el mapa).
class FakeGpsMapPicker extends StatefulWidget {
  const FakeGpsMapPicker({
    super.key,
    required this.position,
    required this.onPositionChanged,
    this.height = 260,
  });

  final LatLng position;
  final ValueChanged<LatLng> onPositionChanged;
  final double height;

  @override
  State<FakeGpsMapPicker> createState() => _FakeGpsMapPickerState();
}

class _FakeGpsMapPickerState extends State<FakeGpsMapPicker> {
  late final MapController _mapController;
  late LatLng _marker;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _marker = widget.position;
  }

  @override
  void didUpdateWidget(FakeGpsMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) {
      _marker = widget.position;
      _mapController.move(widget.position, _mapController.camera.zoom);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onTap(LatLng point) {
    setState(() => _marker = point);
    widget.onPositionChanged(point);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _marker,
            initialZoom: 14,
            onTap: (_, point) => _onTap(point),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
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
                  point: _marker,
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.my_location,
                    size: 40,
                    color: colorScheme.primary,
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
