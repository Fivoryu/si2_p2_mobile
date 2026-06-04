import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/location_service.dart';

class SettingsTecnicoScreen extends ConsumerWidget {
  const SettingsTecnicoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationSvc = LocationService();
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
                    'Activa esta opción para simular tu ubicación GPS durante pruebas.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StatefulBuilder(
                    builder: (context, setState) {
                      return SwitchListTile(
                        title: const Text('Usar GPS simulado'),
                        subtitle: Text(
                          locationSvc.usarFakeGps
                              ? 'GPS fake activo'
                              : 'GPS real activo',
                        ),
                        value: locationSvc.usarFakeGps,
                        onChanged: (value) {
                          setState(() {
                            locationSvc.setUsarFakeGps(value);
                          });
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      const Text(
                        'Coordenadas Fake',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Latitud: ${locationSvc.fakeLat.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Longitud: ${locationSvc.fakeLng.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Por defecto usa coordenadas de Santa Cruz, Bolivia.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
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
                      'Para probar el tracking: entra a una asignación aceptada y presiona "Simular ruta". '
                      'El cliente podrá ver tu posición simulada en el mapa.',
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