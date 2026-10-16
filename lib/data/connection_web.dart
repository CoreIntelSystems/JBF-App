import 'dart:io';

import 'package:drift/wasm.dart';

import 'database.dart';

const databaseFileName = 'jbf.db';

/// The browser build keeps no database file; the data lives in the
/// browser's own storage.
Future<File> appDatabaseFile() async =>
    throw UnsupportedError('The web app has no database file.');

/// Opens the app's database in the browser (a web worker with OPFS or
/// IndexedDB storage). The browser keeps it inside this site's private
/// storage; it is not encrypted with [hexKey] as the phone's file is.
Future<AppDatabase> openAppDatabase({required String hexKey}) async {
  final result = await WasmDatabase.open(
    // A new name so browsers that kept a half-filled copy from the first
    // web build start clean.
    databaseName: 'jbf_web2',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
  );
  return AppDatabase(result.resolvedExecutor);
}

/// In-memory database, for tools.
AppDatabase openInMemoryDatabase() =>
    throw UnsupportedError('Not available in the browser.');

/// Not used in the browser.
AppDatabase openDatabaseFile(File file, {required String hexKey}) =>
    throw UnsupportedError('Not available in the browser.');

// Kept so shared code compiles; the browser database is not encrypted here.
void applyEncryptionKey(dynamic db, String hexKey) {}
