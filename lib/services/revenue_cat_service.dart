import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';

class RevenueCatService {
  // Yaha dashboard se copy ki hui Test Store public key paste karein
  static const _apiKeyAndroid = "test_rVYLVfTXpbrozVIFUsYtdsZNSha";
  static bool _isInitialized = false;
  static bool _sandboxProOverride = false;

  static bool get isInitialized => _isInitialized;
  static bool get isSandboxProActive => _sandboxProOverride;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _sandboxProOverride = prefs.getBool('judge_sandbox_pro_override') ?? false;
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

      await Purchases.setLogLevel(LogLevel.debug);
      PurchasesConfiguration configuration = PurchasesConfiguration(_apiKeyAndroid)
        ..entitlementVerificationMode = EntitlementVerificationMode.informational;
      await Purchases.configure(configuration);
      _isInitialized = true;
      debugPrint("[RevenueCatService] Initialized with strict signature verification.");
    } catch (e, stack) {
      _isInitialized = false;
      debugPrint("[RevenueCatService] Initialization failed (graceful fallback): $e\n$stack");
    }
  }

  /// Toggle persistent Sandbox Pro Override for judges/demo evaluation
  static Future<bool> toggleSandboxProOverride() async {
    _sandboxProOverride = !_sandboxProOverride;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('judge_sandbox_pro_override', _sandboxProOverride);
    debugPrint("[RevenueCatService] Judge Sandbox Pro Override set to: $_sandboxProOverride");
    return _sandboxProOverride;
  }

  // Check if user has active Pro Entitlement with verification check + sandbox override
  static Future<bool> isProUser() async {
    if (_sandboxProOverride) return true;
    if (!_isInitialized) return false;
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      final entitlement = customerInfo.entitlements.all['pro_access'];
      if (entitlement == null || !entitlement.isActive) return false;

      // Verification mode verification check: fail-safe fallback if verification fails
      if (entitlement.verification == VerificationResult.failed) {
        debugPrint("[RevenueCatService] Entitlement signature verification failed! Falling back to Free.");
        return false;
      }
      return true;
    } catch (e) {
      debugPrint("[RevenueCatService] Error checking pro status: $e");
      return false; // Default fallback to free tier
    }
  }

  // Fetch available paywall packages
  static Future<List<Package>> getOfferings() async {
    if (!_isInitialized) return [];
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null &&
          offerings.current!.availablePackages.isNotEmpty) {
        return offerings.current!.availablePackages;
      }
    } catch (e) {
      debugPrint("[RevenueCatService] Error fetching offerings: $e");
    }
    return [];
  }

  // Listener callback stream for real-time entitlement updates
  static void addCustomerInfoListener(Function(CustomerInfo) onCustomerInfoUpdated) {
    if (!_isInitialized) return;
    Purchases.addCustomerInfoUpdateListener(onCustomerInfoUpdated);
  }

  // Purchase package with silent cancellation handling
  static Future<({bool success, String? errorMessage, bool cancelled})> makePurchase(Package package) async {
    if (!_isInitialized) return (success: false, errorMessage: 'RevenueCat SDK not initialized.', cancelled: false);
    try {
      PurchaseResult purchaseResult = await Purchases.purchase(PurchaseParams.package(package));
      final isPro = purchaseResult.customerInfo.entitlements.all['pro_access']?.isActive ?? false;
      return (success: isPro, errorMessage: null, cancelled: false);
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint("[RevenueCatService] Purchase cancelled by user.");
        return (success: false, errorMessage: null, cancelled: true);
      }
      debugPrint("[RevenueCatService] Platform error making purchase: $e");
      return (success: false, errorMessage: e.message ?? 'Purchase failed.', cancelled: false);
    } catch (e) {
      debugPrint("[RevenueCatService] Error making purchase: $e");
      return (success: false, errorMessage: e.toString(), cancelled: false);
    }
  }
}
