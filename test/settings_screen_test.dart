import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:in_salah/providers/app_provider.dart';
import 'package:in_salah/screens/settings_screen.dart';

void main() {
  testWidgets('renders new settings structure and opens profile sheet', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppProvider(),
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Prayer reminders'), findsOneWidget);
    expect(find.text('Iqama times'), findsOneWidget);

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    expect(find.text('My details'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Date of Birth'), findsOneWidget);
  });

  testWidgets('opens prayer reminders sheet from the menu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppProvider(),
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    await tester.tap(find.text('Prayer reminders').first);
    await tester.pumpAndSettle();

    expect(find.text('DAILY REMINDERS'), findsOneWidget);
    expect(find.text('Fajr'), findsOneWidget);
  });

  testWidgets('security sheet does not duplicate profile photo and sign-out', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppProvider(),
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    final accountSettingsText = find.text('Security and access');
    await tester.scrollUntilVisible(
      accountSettingsText,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(accountSettingsText);
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Profile photo'), findsNothing);
    expect(find.text('Securely log out on this device'), findsNothing);
  });
}
