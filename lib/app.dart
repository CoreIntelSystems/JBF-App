import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, KeyEvent;
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_services.dart';
import 'core/org_config.dart';
import 'core/theme.dart';
import 'features/auth/auth_cubit.dart';
import 'features/auth/biometrics.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/setup_screen.dart';
import 'features/home/home_shell.dart';
import 'features/portal/member_shell.dart';

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
    this.clock = DateTime.now,
  });

  final AppServices services;
  final ThemeMode initialThemeMode;
  final BrandPalette palette;
  final Biometrics? biometrics;
  final DateTime Function() clock;

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
        child: _IdleSignOut(
          clock: clock,
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
                    AuthMemberSession(:final session) => MemberShell(
                      key: ValueKey(session.token),
                      session: session,
                    ),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// In a browser, signs out after a quiet spell so an unattended computer
/// does not stay signed in.
class _IdleSignOut extends StatefulWidget {
  const _IdleSignOut({required this.child, required this.clock});
  final Widget child;
  final DateTime Function() clock;

  /// Browser: signs out after this long without a touch or key press.
  static const limit = Duration(minutes: 15);

  /// Phone: signs out after the app has been in the background this long.
  /// Officers handle money and welfare, so they get the shorter limit.
  static const officerAway = Duration(minutes: 5);
  static const memberAway = Duration(minutes: 30);

  @override
  State<_IdleSignOut> createState() => _IdleSignOutState();
}

class _IdleSignOutState extends State<_IdleSignOut>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _wentAway;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      HardwareKeyboard.instance.addHandler(_key);
      _touch();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _wentAway ??= widget.clock();
    } else if (state == AppLifecycleState.resumed) {
      final left = _wentAway;
      _wentAway = null;
      if (left == null || !mounted) return;
      final away = widget.clock().difference(left);
      final auth = context.read<AuthCubit>();
      switch (auth.state) {
        case AuthSignedIn() when away >= _IdleSignOut.officerAway:
          auth.logout();
        case AuthMemberSession() when away >= _IdleSignOut.memberAway:
          auth.memberSignOut();
        default:
      }
    }
  }

  bool _key(KeyEvent _) {
    _touch();
    return false;
  }

  void _touch() {
    _timer?.cancel();
    _timer = Timer(_IdleSignOut.limit, _expire);
  }

  void _expire() {
    if (!mounted) return;
    final auth = context.read<AuthCubit>();
    switch (auth.state) {
      case AuthSignedIn():
        auth.logout();
      case AuthMemberSession():
        auth.memberSignOut();
      default:
    }
    _touch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (kIsWeb) HardwareKeyboard.instance.removeHandler(_key);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => kIsWeb
      ? Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _touch(),
          onPointerMove: (_) => _touch(),
          onPointerSignal: (_) => _touch(),
          child: widget.child,
        )
      : widget.child;
}
