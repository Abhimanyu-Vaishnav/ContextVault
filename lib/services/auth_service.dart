import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class AuthService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check if device hardware supports biometrics or pin/passcode
  static Future<bool> isBiometricsAvailable() async {
    try {
      final canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canAuthenticateWithBiometrics || isDeviceSupported;
    } catch (e) {
      debugPrint('[AuthService] Biometric check error: $e');
      return false;
    }
  }

  /// Trigger native biometric/passcode authentication prompt
  static Future<bool> authenticateUser() async {
    try {
      final isAvailable = await isBiometricsAvailable();
      if (!isAvailable) return true; // Fail open if device has no security hardware

      return await _auth.authenticate(
        localizedReason: 'Unlock ContextVault to access your secure snippets',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Fallback to device PIN/Pattern
        ),
      );
    } catch (e) {
      debugPrint('[AuthService] Authentication error: $e');
      return false;
    }
  }
}
