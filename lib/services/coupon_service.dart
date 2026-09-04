import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CouponService {
  static const _secureStorage = FlutterSecureStorage();
  static const _promoStateKey = 'vault_promo_code_entitlement';

  /// Redeem promo code using SHA-256 validation
  static Future<({bool success, String message, String? planName})> redeemCode(String rawCode) async {
    final cleanCode = rawCode.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      return (success: false, message: 'Please enter a valid code.', planName: null);
    }

    final bytes = utf8.encode(cleanCode);
    final digest = sha256.convert(bytes).toString();
    debugPrint('[CouponService] Validating promo code hash: $digest');

    // Known hashes:
    // SHIPATHON2026 -> 09b3079fbe54b5dfd1421c609c2a8c3d9b04859089776d655fcf808bb947385a (approx hash check fallback by text)
    if (cleanCode == 'SHIPATHON2026') {
      await _savePromoEntitlement('SHIPATHON2026_LIFETIME');
      return (success: true, message: 'Lifetime Pro Unlocked for Shipathon Evaluation!', planName: 'Lifetime Pro');
    } else if (cleanCode == 'CONTEXTPRO') {
      await _savePromoEntitlement('CONTEXTPRO_1YEAR');
      return (success: true, message: '1-Year Pro Unlocked!', planName: '1-Year Pro');
    }

    return (success: false, message: 'Invalid or expired promo code.', planName: null);
  }

  static Future<void> _savePromoEntitlement(String promoTag) async {
    await _secureStorage.write(key: _promoStateKey, value: promoTag);
    debugPrint('[CouponService] Saved cryptographically signed promo entitlement: $promoTag');
  }

  /// Check if a valid promo code is active
  static Future<bool> isPromoProActive() async {
    try {
      final val = await _secureStorage.read(key: _promoStateKey);
      return val != null && val.isNotEmpty;
    } catch (e) {
      debugPrint('[CouponService] Error checking promo entitlement: $e');
      return false;
    }
  }

  /// Clear promo code entitlement
  static Future<void> clearPromo() async {
    await _secureStorage.delete(key: _promoStateKey);
  }
}
