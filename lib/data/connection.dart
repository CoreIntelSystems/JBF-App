import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'database.dart';

const databaseFileName = 'jbf.db';

/// Applies the encryption key and confirms the database can be read.
///
/// The bundled SQLite is SQLite3 Multiple Ciphers, so `PRAGMA key` encrypts
/// the whole file. Opening with a wrong key fails on the first read.
void applyEncryptionKey(Database db, String hexKey) {
  final cipher = db.select('PRAGMA cipher');
  if (cipher.isEmpty) {
    throw StateError(
      'This SQLite build has no encryption support; refusing to store data '
      'unencrypted.',
    );
  }
  db.execute("PRAGMA key = '$hexKey'");
  db.select('SELECT count(*) FROM sqlite_master');
}

/// Opens the app's encrypted database in a background isolate.
Future<AppDatabase> openAppDatabase({required String hexKey}) async {
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, databaseFileName));
  final executor = NativeDatabase.createInBackground(
    file,
    setup: (db) => applyEncryptionKey(db, hexKey),
  );
  return AppDatabase(executor);
}

/// Encrypted database for tests and tools.
AppDatabase openDatabaseFile(File file, {required String hexKey}) =>
    AppDatabase(
      NativeDatabase(file, setup: (db) => applyEncryptionKey(db, hexKey)),
    );

/// In-memory database for tests.
AppDatabase openInMemoryDatabase() => AppDatabase(NativeDatabase.memory());
