import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jbf_app/data/connection.dart';

void main() {
  test('database file is encrypted and needs the key', () async {
    final dir = await Directory.systemTemp.createTemp('jbf_enc');
    final file = File('${dir.path}/jbf.db');
    const key =
        '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

    final db = openDatabaseFile(file, hexKey: key);
    expect(await db.select(db.members).get(), isEmpty); // creates + seeds
    await db.close();

    final bytes = await file.readAsBytes();
    expect(String.fromCharCodes(bytes.take(15)), isNot('SQLite format 3'));

    final again = openDatabaseFile(file, hexKey: key);
    expect((await again.select(again.zones).get()).length, 8);
    await again.close();

    final wrong = openDatabaseFile(file, hexKey: 'ff$key'.substring(0, 64));
    await expectLater(wrong.select(wrong.zones).get(), throwsA(anything));
    await wrong.close().catchError((_) {});
    await dir.delete(recursive: true);
  });
}
