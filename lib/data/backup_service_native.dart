import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../domain/password_hasher.dart';
import 'connection.dart';
import 'database.dart';

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What a backup file contains, shown before restoring it.
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

/// Encrypted backups.
///
/// A `.jbf` backup is a copy of the database re-encrypted with a key derived
/// from a backup password, so it can be restored on a new phone. Automatic
/// daily backups stay on this phone, encrypted with the device key, and
/// protect against mistakes or a damaged database.
class BackupService {
  BackupService({
    required this.db,
    required this.databaseKey,
    required this.databaseFile,
    required this.workDir,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final AppDatabase db;
  final Future<String> Function() databaseKey;
  final File databaseFile;

  /// Holds temporary files and the `backups` folder.
  final Directory workDir;
  final DateTime Function() _now;

  static const _magic = 'JBFBACKUP1\n';
  static const _saltLength = 16;
  static const keepAutoBackups = 7;

  Directory get _autoDir => Directory(p.join(workDir.path, 'backups'));

  File _temp(String name) =>
      File(p.join(workDir.path, 'tmp-${_now().microsecondsSinceEpoch}-$name'));

  Future<void> _vacuumInto(File target) async {
    if (target.existsSync()) target.deleteSync();
    final path = target.path.replaceAll("'", "''");
    await db.customStatement("VACUUM INTO '$path'");
  }

  static void _rekey(File file, String fromKey, String toKey) {
    final d = sqlite3.open(file.path);
    try {
      applyEncryptionKey(d, fromKey);
      d.execute("PRAGMA rekey = '$toKey'");
    } finally {
      d.close();
    }
  }

  static String _hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

  static Future<String> _passwordKey(String password, List<int> salt) async =>
      _hex(await PasswordHasher.deriveKey(password, salt));

  /// A password-protected copy of everything, for moving to a new phone or
  /// keeping off the phone.
  Future<Uint8List> createBackup(String password) async {
    if (password.length < 10) {
      throw BackupException('Use a backup password of at least 10 characters.');
    }
    final tmp = _temp('backup.db');
    try {
      await _vacuumInto(tmp);
      final r = Random.secure();
      final salt = List<int>.generate(_saltLength, (_) => r.nextInt(256));
      _rekey(tmp, await databaseKey(), await _passwordKey(password, salt));
      return Uint8List.fromList([
        ...ascii.encode(_magic),
        ...salt,
        ...await tmp.readAsBytes(),
      ]);
    } finally {
      if (tmp.existsSync()) tmp.deleteSync();
    }
  }

  (List<int>, Uint8List) _split(Uint8List bytes) {
    final head = ascii.encode(_magic);
    if (bytes.length < head.length + _saltLength + 512) {
      throw BackupException('This is not a JBF backup file.');
    }
    for (var i = 0; i < head.length; i++) {
      if (bytes[i] != head[i]) {
        throw BackupException('This is not a JBF backup file.');
      }
    }
    final salt = bytes.sublist(head.length, head.length + _saltLength);
    return (salt, bytes.sublist(head.length + _saltLength));
  }

  static BackupInfo _info(File file, String key) {
    final d = sqlite3.open(file.path);
    try {
      try {
        applyEncryptionKey(d, key);
      } on SqliteException {
        throw BackupException('Wrong backup password.');
      }
      int count(String table) =>
          d.select('SELECT count(*) AS n FROM $table').first['n'] as int;
      final org = d.select('SELECT name FROM org_settings LIMIT 1');
      final last = d.select('SELECT max(at) AS at FROM audit_logs');
      final at = last.first['at'];
      return BackupInfo(
        orgName: org.isEmpty ? '' : org.first['name'] as String,
        members: count('members'),
        payments: count('payments'),
        lastActivity: at == null ? null : DateTime.tryParse('$at'),
      );
    } finally {
      d.close();
    }
  }

  /// Checks the password and describes the backup without changing
  /// anything.
  Future<BackupInfo> inspect(Uint8List bytes, String password) async {
    final (salt, body) = _split(bytes);
    final tmp = _temp('inspect.db');
    try {
      await tmp.writeAsBytes(body, flush: true);
      return _info(tmp, await _passwordKey(password, salt));
    } finally {
      if (tmp.existsSync()) tmp.deleteSync();
    }
  }

  /// Prepares a backup for restoring: decrypts it with [password] and
  /// re-encrypts it with this phone's key. Call [replaceDatabase] with the
  /// result once the app's database is closed.
  Future<File> prepareRestore(Uint8List bytes, String password) async {
    final (salt, body) = _split(bytes);
    final tmp = _temp('restore.db');
    await tmp.writeAsBytes(body, flush: true);
    final key = await _passwordKey(password, salt);
    try {
      _info(tmp, key);
      _rekey(tmp, key, await databaseKey());
      return tmp;
    } catch (_) {
      if (tmp.existsSync()) tmp.deleteSync();
      rethrow;
    }
  }

  /// Replaces the live database with [prepared]. The app's database must be
  /// closed first, and the app restarted afterwards. The previous database
  /// is kept as `jbf.db.before-restore`.
  Future<void> replaceDatabase(File prepared) async {
    if (databaseFile.existsSync()) {
      await databaseFile.copy('${databaseFile.path}.before-restore');
    }
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final f = File('${databaseFile.path}$suffix');
      if (f.existsSync()) f.deleteSync();
    }
    await prepared.copy(databaseFile.path);
    await prepared.delete();
  }

  // ---- Automatic backups ---------------------------------------------------

  Future<List<AutoBackup>> autoBackups() async {
    if (!_autoDir.existsSync()) return const [];
    final out = <AutoBackup>[];
    for (final f in _autoDir.listSync().whereType<File>()) {
      final m = RegExp(r'auto-(\d{8})-(\d{4})\.db$').firstMatch(f.path);
      if (m == null) continue;
      final d = m.group(1)!, t = m.group(2)!;
      out.add(
        AutoBackup(
          f,
          DateTime(
            int.parse(d.substring(0, 4)),
            int.parse(d.substring(4, 6)),
            int.parse(d.substring(6, 8)),
            int.parse(t.substring(0, 2)),
            int.parse(t.substring(2, 4)),
          ),
        ),
      );
    }
    out.sort((a, b) => b.takenAt.compareTo(a.takenAt));
    return out;
  }

  /// Takes a copy if the newest is older than a day, keeping the last
  /// [keepAutoBackups]. Returns the new backup, if one was taken.
  Future<AutoBackup?> autoBackupIfDue() async {
    final existing = await autoBackups();
    final now = _now();
    if (existing.isNotEmpty &&
        now.difference(existing.first.takenAt) < const Duration(hours: 24)) {
      return null;
    }
    _autoDir.createSync(recursive: true);
    String two(int n) => n.toString().padLeft(2, '0');
    final name =
        'auto-${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}.db';
    final file = File(p.join(_autoDir.path, name));
    await _vacuumInto(file);
    final all = await autoBackups();
    for (final old in all.skip(keepAutoBackups)) {
      old.file.deleteSync();
    }
    return AutoBackup(
      file,
      DateTime(now.year, now.month, now.day, now.hour, now.minute),
    );
  }

  /// Copies an automatic backup so it can be passed to [replaceDatabase].
  Future<File> prepareAutoRestore(AutoBackup backup) async {
    final tmp = _temp('restore.db');
    await backup.file.copy(tmp.path);
    _info(tmp, await databaseKey());
    return tmp;
  }
}
