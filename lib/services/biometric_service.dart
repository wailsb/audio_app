import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> hasEnrolledBiometrics() async {
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  Future<BiometricAuthResult> authenticate({
    String reason = 'Vérifiez votre identité',
  }) async {
    try {
      final success = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return BiometricAuthResult(success: success);
    } on PlatformException catch (e) {
      return BiometricAuthResult(
        success: false,
        errorMessage: e.message ?? 'Erreur biométrique.',
      );
    }
  }
}

class BiometricAuthResult {
  final bool success;
  final String? errorMessage;

  const BiometricAuthResult({
    required this.success,
    this.errorMessage,
  });
}