import 'package:flutter/material.dart';

import 'app.dart';
import 'app_services.dart';
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
  runApp(
    JbfApp(
      services: AppServices(db: db, store: store, deviceId: deviceId),
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
