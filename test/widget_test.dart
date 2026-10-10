import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:procesal_plazos/main.dart';

void main() {
  testWidgets('App renders correctly smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('es', null);

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const PlazosProcesalesApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Plazos Procesales'), findsWidgets);

    await tester.ensureVisible(find.text('CALCULAR Y REGISTRAR PLAZO LEGAL'));
    await tester.tap(find.text('CALCULAR Y REGISTRAR PLAZO LEGAL'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('RESULTADO DEL CÁLCULO LEGAL DE PLAZO'), findsOneWidget);
    expect(find.textContaining('FECHA MÁXIMA DE PRESENTACIÓN'), findsOneWidget);
    expect(find.text('DESCARGAR PDF'), findsOneWidget);
    expect(find.text('Historial Persistente de Consultas Realizadas (1)'), findsOneWidget);
    expect(find.text('DESCARGAR HISTORIAL PDF'), findsOneWidget);
  });
}
