import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/app.dart';
import 'package:jbf_app/app_services.dart';
import 'package:jbf_app/data/connection.dart';
import 'package:jbf_app/data/secure_store.dart';
import 'package:jbf_app/features/auth/biometrics.dart';
import 'package:jbf_app/features/dashboard/dashboard_screen.dart';
import 'package:jbf_app/features/members/member_form_screen.dart';
import 'package:jbf_app/features/payments/record_payment_screen.dart';

class _NoBiometrics extends Biometrics {
  @override
  Future<bool> isAvailable() async => false;
}

/// Pumps until [finder] appears, letting real async work (isolates, the
/// database) run between frames.
Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

void main() {
  testWidgets('first run: create admin, land on dashboard, see zones', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    // A typical Android phone with larger text, where layouts overflow first.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final db = openInMemoryDatabase();
    final services = AppServices(
      db: db,
      store: SecureStore(),
      deviceId: 'test',
    );
    await tester.pumpWidget(
      JbfApp(services: services, biometrics: _NoBiometrics()),
    );

    await pumpUntil(tester, find.text('Create account'));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Ama Owusu');
    await tester.enterText(fields.at(1), 'ama');
    await tester.enterText(fields.at(2), 'secret1');
    await tester.enterText(fields.at(3), 'secret1');
    await tester.ensureVisible(find.text('Create account'));
    await tester.pump();
    await tester.tap(find.text('Create account'));

    await pumpUntil(tester, find.text('Hello, Ama Owusu'));
    expect(find.text('Super Administrator'), findsOneWidget);
    await pumpUntil(tester, find.text('Total members'));
    await tester.scrollUntilVisible(
      find.text('Zone 8 (Abrempong)'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(DashboardScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Zone 8 (Abrempong)'), findsOneWidget);

    // Register a member: a third zone is refused with a warning.
    await tester.tap(find.text('Members'));
    await pumpUntil(tester, find.text('Add member'));
    await tester.tap(find.text('Add member'));
    await pumpUntil(tester, find.byType(MemberFormScreen));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, 'Kofi Mensah');
    final formScroll = find
        .descendant(
          of: find.byType(MemberFormScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'Mobile number *'),
      200,
      scrollable: formScroll,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mobile number *'),
      '0241234567',
    );
    for (final z in [
      'Zone 1 (Legends)',
      'Zone 2 (Pacesetters)',
      'Zone 3 (Elite)',
    ]) {
      await tester.scrollUntilVisible(
        find.widgetWithText(FilterChip, z),
        200,
        scrollable: formScroll,
      );
      await tester.tap(find.widgetWithText(FilterChip, z));
      await tester.pump();
    }
    expect(find.textContaining('at most 2 zones'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Primary zone'),
      200,
      scrollable: formScroll,
    );
    expect(find.text('Primary zone'), findsOneWidget);

    final registerButton = find.widgetWithText(FilledButton, 'Register member');
    await tester.scrollUntilVisible(
      registerButton,
      200,
      scrollable: formScroll,
    );
    await tester.pump();
    await tester.tap(registerButton);
    await pumpUntil(tester, find.text('Kofi Mensah'));
    expect(find.textContaining('JBF-000001'), findsWidgets);

    // Record a dues payment for Kofi and get a receipt.
    // Dismiss the queued zone-limit and registered snack bars.
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
        .clearSnackBars();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Payments'));
    await pumpUntil(tester, find.text('Record payment'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Record payment'));
    await pumpUntil(tester, find.text('Choose member'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Choose member'));
    await pumpUntil(tester, find.text('Kofi Mensah'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Kofi Mensah'));
    await pumpUntil(tester, find.text('Month paid for'));
    expect(find.text('Monthly welfare dues'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '20');
    final save = find.text('Save and issue receipt');
    await tester.scrollUntilVisible(
      save,
      200,
      scrollable: find
          .descendant(
            of: find.byType(RecordPaymentScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
    await tester.tap(save);
    await pumpUntil(tester, find.text('Payment saved'));
    expect(find.textContaining('RCP-'), findsWidgets);
    expect(find.text('GHS 20.00'), findsOneWidget);
    expect(find.text('Share receipt (PDF)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    // Let snack bars and drift's stream clean-up timers finish.
    await tester.pump(const Duration(seconds: 5));
    // The in-memory database is dropped with the test; closing it from the
    // fake-async test zone would wait on stream queries that never resume.
  });
}
