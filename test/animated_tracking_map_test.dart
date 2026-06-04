import 'package:emergencias_mobile/shared/widgets/animated_tracking_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('AnimatedTrackingMap shows technician animation data', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedTrackingMap(
            clienteLatLng: const LatLng(-17.7833, -63.1821),
            tecnicoLatLng: const LatLng(-17.7901, -63.1802),
            progresoRuta: 0.5,
            distanciaRestanteKm: 0.75,
            tiempoRestanteMin: 2,
            showTiles: false,
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text(' Cliente'), findsOneWidget);
    expect(find.text('Técnico'), findsOneWidget);
    expect(find.text('750 m'), findsOneWidget);
    expect(find.text('2 min'), findsOneWidget);
    expect(find.byIcon(Icons.local_shipping), findsOneWidget);
  });

  testWidgets('AnimatedTrackingMap shows waiting panel without technician', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedTrackingMap(
            clienteLatLng: const LatLng(-17.7833, -63.1821),
            showTiles: false,
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Esperando ubicación del técnico...'), findsOneWidget);
    expect(find.byIcon(Icons.local_shipping), findsNothing);
  });
}
