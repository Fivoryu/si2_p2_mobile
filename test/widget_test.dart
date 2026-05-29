import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:emergencias_mobile/main.dart';

void main() {
  testWidgets('App loads login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: EmergenciasApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Emergencias Vial'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
