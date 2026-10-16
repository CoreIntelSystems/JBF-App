import 'dart:io';

import 'package:drift/wasm.dart';
import 'package:web/web.dart' as web;

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
  // A new name so browsers that kept a half-filled copy from the first
  // web build start clean.
  const name = 'jbf_web2';
  final sqlite3Uri = Uri.parse('sqlite3.wasm');
  final driftWorkerUri = Uri.parse('drift_worker.js');
  // A sign-out asked for everything stored in this browser to be erased.
  // That happens here, before the database is opened, so nothing holds it.
  if (web.window.localStorage.getItem(_wipeFlag) != null) {
    final probe = await WasmDatabase.probe(
      sqlite3Uri: sqlite3Uri,
      driftWorkerUri: driftWorkerUri,
      databaseName: name,
    );
    for (final existing in probe.existingDatabases) {
      await probe.deleteDatabase(existing);
    }
    web.window.localStorage.clear();
    web.window.sessionStorage.clear();
  }
  final result = await WasmDatabase.open(
    databaseName: name,
    sqlite3Uri: sqlite3Uri,
    driftWorkerUri: driftWorkerUri,
  );
  return AppDatabase(result.resolvedExecutor);
}

const _wipeFlag = 'jbf_wipe_on_start';

/// Marks this browser to be erased and reloads the page. Called after a
/// sign-out so nothing stays behind on a shared computer.
void wipeBrowserAndReload() {
  web.window.localStorage.setItem(_wipeFlag, '1');
  web.window.location.reload();
}

/// In-memory database, for tools.
AppDatabase openInMemoryDatabase() =>
    throw UnsupportedError('Not available in the browser.');

/// Not used in the browser.
AppDatabase openDatabaseFile(File file, {required String hexKey}) =>
    throw UnsupportedError('Not available in the browser.');

// Kept so shared code compiles; the browser database is not encrypted here.
void applyEncryptionKey(dynamic db, String hexKey) {}
