import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:stockflow/data/app_store.dart';
import 'package:stockflow/main.dart';
import 'package:stockflow/screens/admin/analytics_screen.dart';
import 'package:stockflow/screens/admin/import_stock_screen.dart';
import 'package:stockflow/screens/customer/order_form.dart';

Widget _wrap(Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStore()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: MaterialApp(home: child),
    );

void _big(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('AnalyticsScreen builds without throwing', (tester) async {
    _big(tester);
    await tester.pumpWidget(_wrap(const Scaffold(body: AnalyticsScreen())));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ImportStockScreen builds without throwing', (tester) async {
    _big(tester);
    await tester.pumpWidget(_wrap(const ImportStockScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('OrderForm builds without throwing', (tester) async {
    _big(tester);
    await tester.pumpWidget(_wrap(const Scaffold(body: OrderForm(name: 'Test', phone: ''))));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
