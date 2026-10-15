import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_services.dart';
import 'core/org_config.dart';
import 'core/theme.dart';
import 'features/auth/auth_cubit.dart';
import 'features/auth/biometrics.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/setup_screen.dart';
import 'features/home/home_shell.dart';

class ThemeModeCubit extends Cubit<ThemeMode> {
  ThemeModeCubit(this._services, super.initial);
  final AppServices _services;

  Future<void> set(ThemeMode mode) async {
    emit(mode);
    await _services.store.setThemeMode(mode.name);
  }
}

/// Loads cloud sync and keeps it running while the app is open.
class _CloudSync extends StatefulWidget {
  const _CloudSync({required this.child});
  final Widget child;

  @override
  State<_CloudSync> createState() => _CloudSyncState();
}

class _CloudSyncState extends State<_CloudSync> {
  late final _sync = context.read<AppServices>().sync;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _sync.load().then((_) {
      if (_sync.state.enabled) _sync.startAuto();
    }).ignore();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (_sync.state.enabled) _sync.syncNow().ignore();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _sync.stopAuto();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class JbfApp extends StatelessWidget {
  const JbfApp({
    super.key,
    required this.services,
    this.initialThemeMode = ThemeMode.system,
    this.palette = const BrandPalette(),
    this.biometrics,
  });

  final AppServices services;
  final ThemeMode initialThemeMode;
  final BrandPalette palette;
  final Biometrics? biometrics;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: services,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                AuthCubit(services, biometrics ?? Biometrics())..start(),
          ),
          BlocProvider(
            create: (_) => ThemeModeCubit(services, initialThemeMode),
          ),
          BlocProvider.value(value: services.sync),
        ],
        child: _CloudSync(
          child: BlocBuilder<ThemeModeCubit, ThemeMode>(
            builder: (context, mode) => MaterialApp(
              title: OrgDefaults.name,
              debugShowCheckedModeBanner: false,
              theme: buildTheme(Brightness.light, palette),
              darkTheme: buildTheme(Brightness.dark, palette),
              themeMode: mode,
              home: BlocBuilder<AuthCubit, AuthState>(
                builder: (context, state) => switch (state) {
                  AuthChecking() => const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  ),
                  AuthNeedsSetup() => const SetupScreen(),
                  AuthSignedOut() => LoginScreen(
                    key: ValueKey(state),
                    state: state,
                  ),
                  AuthSignedIn() => const HomeShell(),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
