import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Биометрия устройства как альтернатива Родительскому PIN-коду.
class BiometricService {
  BiometricService([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;

  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Подтвердите, что вы взрослый, чтобы выйти из детского режима',
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }
}
