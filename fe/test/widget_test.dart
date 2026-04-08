import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sapahse/main.dart';

void main() {
  testWidgets('SapaHse app launches and shows splash screen',
      (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const BBEApp());

    // Splash screen should be visible first
    expect(find.text('SapaHse'), findsOneWidget);
    expect(find.text('PT. Bukit Baiduri Energi'), findsOneWidget);
  });

  testWidgets('Splash screen has correct background color',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BBEApp());

    // Find Scaffold on splash screen
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, Colors.white);
  });
}