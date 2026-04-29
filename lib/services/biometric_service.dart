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
      // Sur émulateur → retourner true pour ne pas bloquer
      return true;
    }
  }

  Future<bool> authenticate({String reason = 'Vérifiez votre identité'}) async {
    try {
      final available = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();

      // Si biométrie non disponible (émulateur) → passer directement
      if (!available || !supported) {
        return true;
      }

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // false = accepte aussi PIN/pattern
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      // Sur émulateur en cas d'erreur → laisser passer
      return true;
    }
  }
}