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

  @override
  State<AnimatedTrackingMap> createState() => _AnimatedTrackingMapState();
}

class _AnimatedTrackingMapState extends State<AnimatedTrackingMap>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final cliente = widget.clienteLatLng;
    final tecnico = widget.tecnicoLatLng;
    final ruta = widget.rutaCoords;

    final centro = tecnico ?? cliente;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: widget.altura,
            width: double.infinity,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: centro,
                initialZoom: widget.zoom,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
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
                      Polyline(
                        points: ruta,
                        strokeWidth: 4,
                        color: colorScheme.primary.withValues(alpha: 0.6),
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
          ),
        ),
        const SizedBox(height: 8),
        if (tecnico != null)
          _buildInfoPanel(colorScheme)
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
            child: const Text(
              ' Cliente',
              style: TextStyle(
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
                child: const Text(
                  'Técnico',
                  style: TextStyle(
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

  Widget _buildInfoPanel(ColorScheme colorScheme) {
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
          _buildInfoItem(
            Icons.straighten,
            distTxt,
            'Distancia',
            colorScheme,
          ),
          Container(
            width: 1,
            height: 30,
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
          _buildInfoItem(
            Icons.access_time,
            '$tiempo min',
            'Tiempo est.',
            colorScheme,
          ),
          Container(
            width: 1,
            height: 30,
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
          _buildInfoItem(
            Icons.directions_car,
            '${(widget.progresoRuta * 100).toInt()}%',
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
