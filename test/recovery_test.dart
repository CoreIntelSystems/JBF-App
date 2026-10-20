import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/data/secure_store.dart';
import 'package:jbf_app/features/recovery/recovery_screen.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('a missing key is created on first launch', () async {
    final key = await SecureStore().databaseKey();
    expect(key, hasLength(64));
    expect(await SecureStore().databaseKey(), key);
  });

  test('a missing key with an existing database is reported, not replaced', () {
    expect(
      SecureStore().databaseKey(databaseExists: true),
      throwsA(isA<DatabaseKeyLost>()),
    );
  });

  test('an existing key is returned even when the database exists', () async {
    final key = await SecureStore().databaseKey();
    expect(await SecureStore().databaseKey(databaseExists: true), key);
  });

  test('forgetting the key lets a new one be made', () async {
    final store = SecureStore();
    final first = await store.databaseKey();
    await store.forgetDatabaseKey();
    expect(await store.databaseKey(), isNot(first));
  });

  testWidgets('recovery screen erases only after confirmation', (tester) async {
    var erased = 0;
    await tester.pumpWidget(
      RecoveryApp(
        error: const DatabaseKeyLost(),
        onReset: () async => erased++,
      ),
    );
    expect(find.textContaining('cannot be opened'), findsOneWidget);
    await tester.tap(find.byKey(const Key('eraseAndRestart')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(erased, 0);
    await tester.tap(find.byKey(const Key('eraseAndRestart')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmErase')));
    await tester.pumpAndSettle();
    expect(erased, 1);
  });
}
