import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/app.dart';
import 'package:jbf_app/app_services.dart';
import 'package:jbf_app/data/connection.dart';
import 'package:jbf_app/data/secure_store.dart';
import 'package:jbf_app/features/auth/biometrics.dart';

class _NoBiometrics extends Biometrics {
  @override
  Future<bool> isAvailable() async => false;
}

Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

/// Moves the app out of view and back the way Android does, one legal step
/// at a time.
void goAway(WidgetTester tester) {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

void comeBack(WidgetTester tester) {
  for (final s in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

void main() {
  testWidgets('an officer is signed out after 5 minutes in the background', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var now = DateTime(2026, 10, 20, 9);
    final services = AppServices(
      db: openInMemoryDatabase(),
      store: SecureStore(),
      deviceId: 'test',
    );
    await tester.pumpWidget(
      JbfApp(
        services: services,
        biometrics: _NoBiometrics(),
        clock: () => now,
      ),
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

    // A short trip to another app keeps the session.
    goAway(tester);
    now = now.add(const Duration(minutes: 2));
    comeBack(tester);
    await tester.pump();
    expect(find.text('Hello, Ama Owusu'), findsOneWidget);

    // A long one asks for the password again.
    goAway(tester);
    now = now.add(const Duration(minutes: 6));
    comeBack(tester);
    await pumpUntil(tester, find.text('Sign in'));
    expect(find.text('Hello, Ama Owusu'), findsNothing);

    // Let the database's stream clean-up timers run before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
