import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:stockflow/data/app_store.dart';
import 'package:stockflow/main.dart';
import 'package:stockflow/screens/entry_screen.dart';

void main() {
  testWidgets('Entry screen shows the role options', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppStore()),
          ChangeNotifierProvider(create: (_) => ThemeController()),
        ],
        child: const MaterialApp(home: EntryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('StockFlow'), findsWidgets);
    expect(find.text('Admin Console'), findsOneWidget);
    expect(find.text('Customer Order'), findsOneWidget);
  });
}
