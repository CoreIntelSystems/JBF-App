import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Thin wrapper around the device fingerprint / face check.
class Biometrics {
  Biometrics([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> confirm(String reason) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }
}
