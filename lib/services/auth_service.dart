import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const String _keyBiometricsEnabled = 'cv_biometrics_enabled';

  /// Check if biometrics option is enabled in Settings (Default: false)
  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricsEnabled) ?? false;
  }

  /// Enable or disable biometrics setting
  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricsEnabled, enabled);
  }

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
  static Future<bool> authenticateUser({String? reason}) async {
    try {
      final isAvailable = await isBiometricsAvailable();
      if (!isAvailable) return true; // Fail open if device has no security hardware

      return await _auth.authenticate(
        localizedReason: reason ?? 'Unlock ContextVault to access your secure snippets',
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
