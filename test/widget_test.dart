import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:procesal_plazos/main.dart';

void main() {
  testWidgets('App renders correctly smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const PlazosProcesalesApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Plazos Procesales'), findsWidgets);
  });
}
