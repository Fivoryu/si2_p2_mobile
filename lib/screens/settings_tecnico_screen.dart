import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';
import '../services/technician_location_broadcaster.dart';
import '../shared/widgets/fake_gps_map_picker.dart';

class SettingsTecnicoScreen extends StatefulWidget {
  const SettingsTecnicoScreen({super.key});

  @override
  State<SettingsTecnicoScreen> createState() => _SettingsTecnicoScreenState();
}

class _SettingsTecnicoScreenState extends State<SettingsTecnicoScreen> {
  final _locationSvc = LocationService();
  late bool _usarFake;
  late LatLng _posicion;
  bool _obteniendoGps = false;

  @override
  void initState() {
    super.initState();
    _usarFake = _locationSvc.usarFakeGps;
    _posicion = LatLng(_locationSvc.fakeLat, _locationSvc.fakeLng);
  }

  void _aplicarPosicion(LatLng point) {
    setState(() => _posicion = point);
    _locationSvc.setFakeCoords(point.latitude, point.longitude);
    TechnicianLocationBroadcaster.instance.sendNow();
  }

  Future<void> _usarUbicacionReal() async {
    setState(() => _obteniendoGps = true);
    try {
      final prev = _locationSvc.usarFakeGps;
      _locationSvc.setUsarFakeGps(false);
      final pos = await _locationSvc.current();
      _locationSvc.setUsarFakeGps(prev);
      _aplicarPosicion(LatLng(pos.latitude, pos.longitude));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ubicación actual aplicada al mapa')),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo obtener GPS: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _obteniendoGps = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.gps_fixed, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text(
                        'GPS de Simulación',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Activa esta opción para simular tu ubicación GPS durante pruebas. '
                    'Con una asignación en camino, la app envía tu posición automáticamente cada pocos segundos mientras estés en Mi Taller.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Usar GPS simulado'),
                    subtitle: Text(
                      _usarFake ? 'GPS fake activo' : 'GPS real activo',
                    ),
                    value: _usarFake,
                    onChanged: (value) {
                      setState(() => _usarFake = value);
                      _locationSvc.setUsarFakeGps(value);
                      TechnicianLocationBroadcaster.instance.sendNow();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? 'GPS simulado activado'
                                : 'GPS real activado',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.map_outlined, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text(
                        'Ubicación simulada',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _usarFake
                        ? 'Toca el mapa para elegir dónde aparecerás en las pruebas.'
                        : 'Activa el GPS simulado para seleccionar una ubicación en el mapa.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Latitud: ${_posicion.latitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Longitud: ${_posicion.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_usarFake) ...[
                    const SizedBox(height: 16),
                    FakeGpsMapPicker(
                      position: _posicion,
                      onPositionChanged: _aplicarPosicion,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _obteniendoGps ? null : _usarUbicacionReal,
                      icon: _obteniendoGps
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            )
                          : const Icon(Icons.near_me),
                      label: const Text('Usar mi ubicación GPS real'),
                    ),
                  ] else
                    const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            color: colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Para probar el tracking: elige tu punto en el mapa, entra a una '
                      'asignación aceptada y presiona "Simular ruta". El cliente verá '
                      'tu posición desde la ubicación seleccionada.',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
