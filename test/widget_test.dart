import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:charity/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Provide mock initial values for SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Build our app and trigger a frame with prefs
    await tester.pumpWidget(const MyApp());

    // Since your real app doesn’t have a counter anymore,
    // you may want to test for something else.
    // For now, let's just check that the splash screen shows:
    expect(find.text('Charity Connect'), findsOneWidget);
  });
}