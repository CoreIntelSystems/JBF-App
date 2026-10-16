import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'app_services.dart';
import 'core/reminders.dart';
import 'data/backup_service.dart';
import 'data/connection.dart';
import 'core/theme.dart';
import 'data/secure_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SecureStore();
  final key = await store.databaseKey();
  final deviceId = await store.deviceId();
  final db = await openAppDatabase(hexKey: key);
  final themeMode = await store.themeMode();
  final org = await db.select(db.orgSettings).getSingle();
  // Backups copy the database file, which phones have and browsers do not.
  final BackupService? backup = kIsWeb
      ? null
      : BackupService(
          db: db,
          databaseKey: () async => key,
          databaseFile: await appDatabaseFile(),
          workDir: Directory((await getApplicationSupportDirectory()).path),
        );
  // A daily safety copy on this phone; failures must never block start-up.
  backup?.autoBackupIfDue().ignore();
  runApp(
    JbfApp(
      services: AppServices(
        db: db,
        store: store,
        deviceId: deviceId,
        backup: backup,
        reminders: LocalReminders(store),
      ),
      initialThemeMode: ThemeMode.values.firstWhere(
        (m) => m.name == themeMode,
        orElse: () => ThemeMode.system,
      ),
      palette: BrandPalette(
        primary: Color(org.primaryColor),
        accent: Color(org.accentColor),
      ),
    ),
  );
}
