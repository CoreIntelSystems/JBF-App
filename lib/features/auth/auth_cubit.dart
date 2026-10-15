import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../data/repositories/auth_repository.dart';
import 'biometrics.dart';

sealed class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthChecking extends AuthState {
  const AuthChecking();
}

/// No users exist yet: show first-run setup.
class AuthNeedsSetup extends AuthState {
  const AuthNeedsSetup();
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.lastUsername, this.biometricReady = false});
  final String? lastUsername;

  /// The last user switched fingerprint on and this device supports it.
  final bool biometricReady;
  @override
  List<Object?> get props => [lastUsername, biometricReady];
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user);
  final AppUser user;
  @override
  List<Object?> get props => [user];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._services, this._biometrics) : super(const AuthChecking());

  final AppServices _services;
  final Biometrics _biometrics;

  AuthRepository get _auth => _services.auth;
  String get _deviceId => _services.deviceId;

  @override
  void emit(AuthState state) {
    // Zone leaders only see their own zone(s) everywhere in the app.
    _services.scope.zoneIds = switch (state) {
      AuthSignedIn(:final user) => user.zoneScope,
      _ => null,
    };
    super.emit(state);
  }

  AppUser? get user => switch (state) {
    AuthSignedIn(:final user) => user,
    _ => null,
  };

  Future<void> start() async {
    if (!await _auth.hasUsers()) {
      emit(const AuthNeedsSetup());
      return;
    }
    await _signedOut();
  }

  Future<void> _signedOut() async {
    final last = await _services.store.lastUsername();
    final ready =
        last != null &&
        await _auth.biometricEnabledFor(last) &&
        await _biometrics.isAvailable();
    emit(AuthSignedOut(lastUsername: last, biometricReady: ready));
  }

  Future<void> setup({
    required String displayName,
    required String username,
    required String password,
    String? pin,
  }) async {
    final user = await _auth.createInitialAdmin(
      displayName: displayName,
      username: username,
      password: password,
      pin: pin,
      deviceId: _deviceId,
    );
    await _services.store.setLastUsername(user.username);
    emit(AuthSignedIn(user));
  }

  /// Throws [AuthException] with an on-screen message when it fails.
  Future<void> login(String username, String secret, LoginMethod method) async {
    final user = await _auth.login(
      username,
      secret,
      method: method,
      deviceId: _deviceId,
    );
    await _services.store.setLastUsername(user.username);
    emit(AuthSignedIn(user));
  }

  /// Returns false if the fingerprint check was cancelled or failed.
  Future<bool> loginWithBiometrics() async {
    final s = state;
    if (s is! AuthSignedOut || s.lastUsername == null) return false;
    final ok = await _biometrics.confirm('Confirm it is you to open JBF');
    if (!ok) return false;
    await login(s.lastUsername!, '', LoginMethod.biometric);
    return true;
  }

  Future<bool> biometricsAvailable() => _biometrics.isAvailable();

  Future<bool> confirmBiometrics(String reason) => _biometrics.confirm(reason);

  void updateUser(AppUser user) => emit(AuthSignedIn(user));

  Future<void> logout() async {
    final u = user;
    if (u != null) await _auth.logout(u, _deviceId);
    await _signedOut();
  }
}
