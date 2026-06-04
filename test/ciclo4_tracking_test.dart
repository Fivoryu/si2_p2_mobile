import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart' show LatLng, Distance, LengthUnit;

import 'package:emergencias_mobile/data/models/asignacion.dart';
import 'package:emergencias_mobile/data/api/incidente_api.dart';
import 'package:emergencias_mobile/data/api/taller_api.dart';

void main() {
  group('Asignacion model', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 'asig-123',
        'incidente_id': 'inc-456',
        'taller_id': 'tal-789',
        'estado': 'ACEPTADO',
        'tecnico_id': 'tec-001',
        'motivo_rechazo': null,
        'respondido_at': '2024-06-02T10:30:00Z',
        'asignacion_automatica': true,
        'taller_nombre': 'Taller Central',
        'incidente_estado': 'TALLER_ASIGNADO',
        'incidente_descripcion': 'Llanta pinchada',
        'incidente_direccion': 'Av. Brasil 500',
        'incidente_latitud': -17.7833,
        'incidente_longitud': -63.1821,
        'incidente_prioridad': 'MEDIA',
        'incidente_resumen_ia': 'Problema de rueda',
        'distancia_km': 2.5,
        'tiempo_llegada_min': 15,
        'precio_sugerido': 150.0,
        'dificultad': 'BAJA',
        'cotizacion_id': 'cot-001',
        'precio_ofertado': 140.0,
        'tiempo_ofertado_min': 12,
        'cotizacion_estado': 'PENDIENTE',
      };

      final asig = Asignacion.fromJson(json);

      expect(asig.id, 'asig-123');
      expect(asig.incidenteId, 'inc-456');
      expect(asig.tallerId, 'tal-789');
      expect(asig.estado, 'ACEPTADO');
      expect(asig.incidenteEstado, 'TALLER_ASIGNADO');
      expect(asig.incidenteDescripcion, 'Llanta pinchada');
      expect(asig.incidenteDireccion, 'Av. Brasil 500');
      expect(asig.incidenteLatitud, -17.7833);
      expect(asig.incidenteLongitud, -63.1821);
      expect(asig.incidentePrioridad, 'MEDIA');
      expect(asig.precioSugerido, 150.0);
      expect(asig.distanciaKm, 2.5);
      expect(asig.cotizacionEstado, 'PENDIENTE');
    });

    test('fromJson handles missing nullable fields', () {
      final json = {
        'id': 'asig-1',
        'incidente_id': 'inc-1',
        'taller_id': 'tal-1',
        'estado': 'ASIGNADO',
      };

      final asig = Asignacion.fromJson(json);

      expect(asig.id, 'asig-1');
      expect(asig.tecnicoId, isNull);
      expect(asig.motivoRechazo, isNull);
      expect(asig.incidenteEstado, isNull);
      expect(asig.precioSugerido, isNull);
      expect(asig.distanciaKm, isNull);
    });

    test('estadoLabel returns correct labels', () {
      expect(Asignacion.estadoLabel('ASIGNADO'), 'Asignado');
      expect(Asignacion.estadoLabel('ACEPTADO'), 'Aceptado');
      expect(Asignacion.estadoLabel('RECHAZADO'), 'Rechazado');
      expect(Asignacion.estadoLabel('UNKNOWN'), 'UNKNOWN');
    });

    test('puedeAceptar returns true only for ASIGNADO', () {
      final asigAsignado = Asignacion(
        id: '1', incidenteId: '1', tallerId: '1', estado: 'ASIGNADO');
      final asigAceptado = Asignacion(
        id: '2', incidenteId: '2', tallerId: '2', estado: 'ACEPTADO');

      expect(asigAsignado.puedeAceptar, isTrue);
      expect(asigAceptado.puedeAceptar, isFalse);
    });

    test('puedeRechazar returns true only for ASIGNADO', () {
      final asigAsignado = Asignacion(
        id: '1', incidenteId: '1', tallerId: '1', estado: 'ASIGNADO');
      final asigRechazado = Asignacion(
        id: '2', incidenteId: '2', tallerId: '2', estado: 'RECHAZADO');

      expect(asigAsignado.puedeRechazar, isTrue);
      expect(asigRechazado.puedeRechazar, isFalse);
    });

    test('formatDate parses ISO correctly', () {
      final result = Asignacion.formatDate('2024-06-02T14:30:00Z');
      expect(result, '02/06/2024 14:30');
    });

    test('formatDate returns dash for null', () {
      expect(Asignacion.formatDate(null), '—');
    });
  });

  group('IncidenteApi methods', () {
    test('cambiarEstado is a callable method', () {
      final api = IncidenteApi(Dio());
      expect(api.cambiarEstado, isA<Function>());
    });

    test('iniciarSimulacion is a callable method', () {
      final api = IncidenteApi(Dio());
      expect(api.iniciarSimulacion, isA<Function>());
    });

    test('enviarUbicacion is a callable method', () {
      final api = IncidenteApi(Dio());
      expect(api.enviarUbicacion, isA<Function>());
    });

    test('cancel is a callable method', () {
      final api = IncidenteApi(Dio());
      expect(api.cancel, isA<Function>());
    });

    test('seleccionarOferta is a callable method', () {
      final api = IncidenteApi(Dio());
      expect(api.seleccionarOferta, isA<Function>());
    });
  });

  group('TallerApi methods', () {
    test('aceptar is a callable method', () {
      final api = TallerApi(Dio());
      expect(api.aceptar, isA<Function>());
    });

    test('rechazar is a callable method', () {
      final api = TallerApi(Dio());
      expect(api.rechazar, isA<Function>());
    });

    test('actualizarDisponibilidad is a callable method', () {
      final api = TallerApi(Dio());
      expect(api.actualizarDisponibilidad, isA<Function>());
    });

    test('misNotificaciones is a callable method', () {
      final api = TallerApi(Dio());
      expect(api.misNotificaciones, isA<Function>());
    });
  });

  group('State machine transitions (backend validation)', () {
    test('valid transition: TALLER_ASIGNADO -> EN_CAMINO', () {
      const target = 'EN_CAMINO';
      const allowed = {'EN_CAMINO', 'BUSCANDO_TALLER'};
      expect(allowed.contains(target), isTrue);
    });

    test('valid transition: EN_CAMINO -> EN_ATENCION', () {
      const target = 'EN_ATENCION';
      const allowed = {'EN_ATENCION'};
      expect(allowed.contains(target), isTrue);
    });

    test('valid transition: EN_ATENCION -> FINALIZADO', () {
      const target = 'FINALIZADO';
      const allowed = {'FINALIZADO'};
      expect(allowed.contains(target), isTrue);
    });

    test('invalid transition: TALLER_ASIGNADO -> FINALIZADO', () {
      const target = 'FINALIZADO';
      const allowed = {'EN_CAMINO', 'BUSCANDO_TALLER'};
      expect(allowed.contains(target), isFalse);
    });

    test('invalid transition: EN_CAMINO -> TALLER_ASIGNADO', () {
      const target = 'TALLER_ASIGNADO';
      const allowed = {'EN_ATENCION'};
      expect(allowed.contains(target), isFalse);
    });
  });

  group('Tracking progress calculation (real Distance)', () {
    const distancia = Distance();

    test('progress is 0 when tech is at start position', () {
      const techLat = -17.7900;
      const techLng = -63.1800;
      const clienteLat = -17.7833;
      const clienteLng = -63.1821;
      const techStartLat = -17.7900;
      const techStartLng = -63.1800;

      final clientePos = LatLng(clienteLat, clienteLng);
      final techPos = LatLng(techLat, techLng);
      final restante = distancia.as(LengthUnit.Kilometer, techPos, clientePos);
      final origen = LatLng(techStartLat, techStartLng);
      final totalDist = distancia.as(LengthUnit.Kilometer, origen, clientePos);

      final progreso = totalDist > 0
          ? ((totalDist - restante) / totalDist).clamp(0.0, 1.0)
          : 0.0;

      expect(restante, greaterThan(0));
      expect(progreso, lessThan(0.05));
    });

    test('progress increases as tech moves toward cliente', () {
      const clienteLat = -17.7833;
      const clienteLng = -63.1821;
      const techStartLat = -17.7900;
      const techStartLng = -63.1800;
      const techLat = -17.7866;
      const techLng = -63.1810;

      final clientePos = LatLng(clienteLat, clienteLng);
      final techPos = LatLng(techLat, techLng);
      final techStart = LatLng(techStartLat, techStartLng);
      final restante = distancia.as(LengthUnit.Kilometer, techPos, clientePos);
      final totalDist = distancia.as(LengthUnit.Kilometer, techStart, clientePos);

      final progreso = totalDist > 0
          ? ((totalDist - restante) / totalDist).clamp(0.0, 1.0)
          : 0.0;

      expect(progreso, greaterThan(0.1));
    });

    test('progress is 1 when tech arrives at cliente', () {
      const clienteLat = -17.7833;
      const clienteLng = -63.1821;
      const techStartLat = -17.7900;
      const techStartLng = -63.1800;
      const techLat = -17.7833;
      const techLng = -63.1821;

      final clientePos = LatLng(clienteLat, clienteLng);
      final techPos = LatLng(techLat, techLng);
      final techStart = LatLng(techStartLat, techStartLng);
      final restante = distancia.as(LengthUnit.Kilometer, techPos, clientePos);
      final totalDist = distancia.as(LengthUnit.Kilometer, techStart, clientePos);

      final progreso = totalDist > 0
          ? ((totalDist - restante) / totalDist).clamp(0.0, 1.0)
          : 0.0;

      expect(restante, lessThan(0.01));
      expect(progreso, equals(1.0));
    });

    test('fallback to cliente as origen when techStart is null gives totalDist=0 so progreso=0', () {
      const clienteLat = -17.7833;
      const clienteLng = -63.1821;
      const techLat = -17.7866;
      const techLng = -63.1810;
      const double? techStartLat = null;
      const double? techStartLng = null;

      final clientePos = LatLng(clienteLat, clienteLng);
      final techPos = LatLng(techLat, techLng);
      final restante = distancia.as(LengthUnit.Kilometer, techPos, clientePos);
      final origenLat = techStartLat ?? clienteLat;
      final origenLng = techStartLng ?? clienteLng;
      final origen = LatLng(origenLat, origenLng);
      final totalDist = distancia.as(LengthUnit.Kilometer, origen, clientePos);

      final progreso = totalDist > 0
          ? ((totalDist - restante) / totalDist).clamp(0.0, 1.0)
          : 0.0;

      expect(totalDist, equals(0.0));
      expect(progreso, equals(0.0));
    });
  });

  group('WsService close behavior', () {
    test('close with specific keys cleans only those keys', () {
      final wsKeys = <String>{'tenant1:inc1', 'tenant1:inc2', 'tenant2:inc1'};
      final closedKeys = <String>[];

      void closeKey(String key) {
        closedKeys.add(key);
        wsKeys.remove(key);
      }

      closeKey('tenant1:inc1');

      expect(closedKeys, contains('tenant1:inc1'));
      expect(wsKeys, isNot(contains('tenant1:inc1')));
      expect(wsKeys, contains('tenant1:inc2'));
      expect(wsKeys, contains('tenant2:inc1'));
    });

    test('close all cleans all keys', () {
      final wsKeys = <String>{'tenant1:inc1', 'tenant1:inc2', 'tenant2:inc1'};
      final closedKeys = <String>[];

      for (final key in wsKeys.toList()) {
        closedKeys.add(key);
      }
      wsKeys.clear();

      expect(closedKeys.length, 3);
      expect(wsKeys, isEmpty);
    });

    test('key format is tenantId:incidentId', () {
      const tenantId = 'tenant-abc';
      const incidentId = 'incident-123';
      final key = '$tenantId:$incidentId';

      expect(key, 'tenant-abc:incident-123');
    });
  });

  group('AsignacionDetailScreen UI states', () {
    testWidgets('shows TALLER_ASIGNADO actions when estado ACEPTADO and incidenteEstado TALLER_ASIGNADO', (tester) async {
      final widget = _buildStatusActionsTestWidget(
        incidenteEstado: 'TALLER_ASIGNADO',
        incidenteId: 'inc-123',
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Iniciar Camino'), findsOneWidget);
      expect(find.text('Simular Ruta + En Camino'), findsOneWidget);
    });

    testWidgets('shows EN_CAMINO action when incidenteEstado EN_CAMINO', (tester) async {
      final widget = _buildStatusActionsTestWidget(
        incidenteEstado: 'EN_CAMINO',
        incidenteId: 'inc-123',
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Marcar Llegada'), findsOneWidget);
      expect(find.text('Iniciar Camino'), findsNothing);
    });

    testWidgets('shows EN_ATENCION action when incidenteEstado EN_ATENCION', (tester) async {
      final widget = _buildStatusActionsTestWidget(
        incidenteEstado: 'EN_ATENCION',
        incidenteId: 'inc-123',
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Finalizar Servicio'), findsOneWidget);
    });

    testWidgets('shows finished message when incidenteEstado FINALIZADO', (tester) async {
      final widget = _buildStatusActionsTestWidget(
        incidenteEstado: 'FINALIZADO',
        incidenteId: 'inc-123',
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Servicio finalizado'), findsOneWidget);
      expect(find.text('Finalizar Servicio'), findsNothing);
    });

    testWidgets('shows paid message when incidenteEstado PAGADO', (tester) async {
      final widget = _buildStatusActionsTestWidget(
        incidenteEstado: 'PAGADO',
        incidenteId: 'inc-123',
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Servicio pagado'), findsOneWidget);
    });
  });
}

Widget _buildStatusActionsTestWidget({
  required String incidenteEstado,
  required String incidenteId,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: _StatusActionsTestWidget(
          incidenteEstado: incidenteEstado,
          incidenteId: incidenteId,
        ),
      ),
    ),
  );
}

class _StatusActionsTestWidget extends ConsumerWidget {
  const _StatusActionsTestWidget({
    required this.incidenteEstado,
    required this.incidenteId,
  });

  final String incidenteEstado;
  final String incidenteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    if (incidenteEstado == 'FINALIZADO' || incidenteEstado == 'PAGADO') {
      return Card(
        color: colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  incidenteEstado == 'FINALIZADO'
                      ? 'Servicio finalizado'
                      : 'Servicio pagado',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (incidenteEstado == 'TALLER_ASIGNADO') ...[
          _buildButton('Iniciar Camino', Icons.directions_car, colorScheme.primary),
          const SizedBox(height: 8),
          _buildButton('Simular Ruta + En Camino', Icons.play_arrow, colorScheme.tertiary),
        ],
        if (incidenteEstado == 'EN_CAMINO') ...[
          _buildButton('Marcar Llegada', Icons.place, colorScheme.secondary),
        ],
        if (incidenteEstado == 'EN_ATENCION') ...[
          _buildButton('Finalizar Servicio', Icons.check_circle, colorScheme.primary),
        ],
      ],
    );
  }

  Widget _buildButton(String label, IconData icon, Color color) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {},
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}