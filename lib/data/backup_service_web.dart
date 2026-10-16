import 'dart:io';
import 'dart:typed_data';

import 'database.dart';

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BackupInfo {
  const BackupInfo({
    required this.orgName,
    required this.members,
    required this.payments,
    required this.lastActivity,
  });
  final String orgName;
  final int members;
  final int payments;
  final DateTime? lastActivity;
}

class AutoBackup {
  const AutoBackup(this.file, this.takenAt);
  final File file;
  final DateTime takenAt;
}

/// Backups are not available in the browser: the data is kept in the
/// cloud and in the browser's own storage. This stand-in lets shared code
/// compile; the web app never creates one.
class BackupService {
  BackupService({
    required this.db,
    required this.databaseKey,
    required this.databaseFile,
    required this.workDir,
    DateTime Function()? clock,
  });

  final AppDatabase db;
  final Future<String> Function() databaseKey;
  final File databaseFile;
  final Directory workDir;

  static const keepAutoBackups = 7;

  static BackupException get _no =>
      BackupException('Backups are done on the Android app.');

  Future<Uint8List> createBackup(String password) async => throw _no;
  Future<BackupInfo> inspect(Uint8List bytes, String password) async =>
      throw _no;
  Future<File> prepareRestore(Uint8List bytes, String password) async =>
      throw _no;
  Future<void> replaceDatabase(File prepared) async => throw _no;
  Future<List<AutoBackup>> autoBackups() async => const [];
  Future<AutoBackup?> autoBackupIfDue() async => null;
  Future<File> prepareAutoRestore(AutoBackup backup) async => throw _no;
}
