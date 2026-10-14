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

class JbfApp extends StatelessWidget {
  const JbfApp({
    super.key,
    required this.services,
    this.initialThemeMode = ThemeMode.system,
    this.biometrics,
  });

  final AppServices services;
  final ThemeMode initialThemeMode;
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
        ],
        child: BlocBuilder<ThemeModeCubit, ThemeMode>(
          builder: (context, mode) => MaterialApp(
            title: OrgDefaults.name,
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
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
    );
  }
}
