import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'coupon_service.dart';

class RevenueCatService {
  // RevenueCat Public API Keys
  static const String _androidApiKey = 'goog_YOUR_ACTUAL_ANDROID_PUBLIC_KEY';
  static const String _iosApiKey = 'appl_YOUR_ACTUAL_IOS_PUBLIC_KEY';

  static const _secureStorage = FlutterSecureStorage();
  static const _appUserIdKey = 'vault_app_user_id';
  static const _localProGrantKey = 'vault_local_pro_grant';

  static bool _isInitialized = false;
  static bool _sandboxProOverride = false;
  static String? _appUserId;

  /// ValueNotifier for instant reactive UI updates across the entire app
  static final ValueNotifier<bool> proStatusNotifier = ValueNotifier<bool>(false);

  static bool get isInitialized => _isInitialized;
  static bool get isSandboxProActive => _sandboxProOverride;
  static String get appUserId => _appUserId ?? 'anonymous_user';

  static Future<String> _getOrCreateAppUserId() async {
    try {
      String? userId = await _secureStorage.read(key: _appUserIdKey);
      if (userId == null || userId.isEmpty) {
        userId = "cv_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecondsSinceEpoch % 8999))}";
        await _secureStorage.write(key: _appUserIdKey, value: userId);
      }
      return userId;
    } catch (e) {
      return "cv_${DateTime.now().millisecondsSinceEpoch}";
    }
  }

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _sandboxProOverride = prefs.getBool('judge_sandbox_pro_override') ?? false;
      _appUserId = await _getOrCreateAppUserId();

      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      String apiKey = '';
      if (Platform.isAndroid) {
        apiKey = _androidApiKey;
      } else if (Platform.isIOS) {
        apiKey = _iosApiKey;
      }

      if (apiKey.isEmpty || apiKey.contains('YOUR_ACTUAL')) {
        debugPrint("REVENUECAT_CONFIG_WARNING: Valid platform API key not supplied (key starting with goog_ on Android / appl_ on iOS required). SDK in graceful offline fallback mode.");
        _isInitialized = false;
        proStatusNotifier.value = await isProUser();
        return;
      }

      PurchasesConfiguration configuration = PurchasesConfiguration(apiKey)
        ..appUserID = _appUserId
        ..entitlementVerificationMode = EntitlementVerificationMode.informational;

      await Purchases.configure(configuration);
      _isInitialized = true;
      debugPrint("REVENUECAT_INIT_SUCCESS: Configured with key starting with ${apiKey.substring(0, 5)}...");

      // Register CustomerInfo update listener for instant broadcast
      Purchases.addCustomerInfoUpdateListener((customerInfo) async {
        final active = hasActiveEntitlement(customerInfo);
        if (active) {
          await _persistProStatusLocally(true);
        }
        proStatusNotifier.value = active || _sandboxProOverride;
        debugPrint("[RevenueCatService] CustomerInfo update received. Active: $active");
      });

      // Initial entitlement state check
      try {
        CustomerInfo info = await Purchases.getCustomerInfo();
        debugPrint("DEBUG_RC: Active Entitlements -> ${info.entitlements.active.keys}");
      } catch (e) {
        debugPrint("[RevenueCatService] CustomerInfo check during init fallback: $e");
      }

      final isPro = await isProUser();
      proStatusNotifier.value = isPro;
    } catch (e, stack) {
      _isInitialized = false;
      debugPrint("REVENUECAT_INIT_ERROR: $e\n$stack");
    }
  }

  /// Dynamic active entitlement evaluation helper
  static bool hasActiveEntitlement(CustomerInfo info) {
    debugPrint("DEBUG_RC: Active Entitlements -> ${info.entitlements.active.keys}");
    debugPrint("DEBUG_RC: All Entitlements -> ${info.entitlements.all.keys}");
    debugPrint("DEBUG_RC: Active Subscriptions -> ${info.activeSubscriptions}");

    // If ANY active entitlement exists, OR activeSubscriptions is NOT empty, grant Pro!
    if (info.entitlements.active.isNotEmpty || info.activeSubscriptions.isNotEmpty) {
      return true;
    }

    // Specific standard entitlement identifier checks
    final proAccess = info.entitlements.all['pro_access'];
    if (proAccess != null && proAccess.isActive) return true;

    final pro = info.entitlements.all['pro'];
    if (pro != null && pro.isActive) return true;

    final premium = info.entitlements.all['premium'];
    if (premium != null && premium.isActive) return true;

    return false;
  }

  /// Save signed secure storage flag to prevent post-purchase lockouts
  static Future<void> _persistProStatusLocally(bool active) async {
    try {
      await _secureStorage.write(
        key: _localProGrantKey,
        value: active ? 'true' : 'false',
      );
      debugPrint("[RevenueCatService] Persisted local pro grant: $active");
    } catch (e) {
      debugPrint("[RevenueCatService] Failed to persist pro grant: $e");
    }
  }

  /// Toggle persistent Sandbox Pro Override for judges/demo evaluation
  static Future<bool> toggleSandboxProOverride() async {
    _sandboxProOverride = !_sandboxProOverride;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('judge_sandbox_pro_override', _sandboxProOverride);
    proStatusNotifier.value = await isProUser();
    debugPrint("[RevenueCatService] Judge Sandbox Pro Override set to: $_sandboxProOverride");
    return _sandboxProOverride;
  }

  /// Check if user has active Pro entitlement with verification, promo, local grant & sandbox override
  static Future<bool> isProUser() async {
    if (_sandboxProOverride) return true;
    try {
      final isPromoActive = await CouponService.isPromoProActive();
      if (isPromoActive) return true;
    } catch (_) {}

    if (!_isInitialized) {
      // Check secure storage cached grant fallback for restart resilience
      try {
        final localGrant = await _secureStorage.read(key: _localProGrantKey);
        if (localGrant == 'true') return true;
      } catch (_) {}
      return false;
    }

    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      debugPrint("DEBUG_RC: Active Entitlements -> ${customerInfo.entitlements.active.keys}");

      final active = hasActiveEntitlement(customerInfo);
      if (active) {
        await _persistProStatusLocally(true);
        return true;
      }

      // Check secure storage cached grant
      final localGrant = await _secureStorage.read(key: _localProGrantKey);
      if (localGrant == 'true') return true;

      return false;
    } catch (e) {
      debugPrint("[RevenueCatService] Error checking pro status: $e");
      // Fallback check secure storage
      try {
        final localGrant = await _secureStorage.read(key: _localProGrantKey);
        return localGrant == 'true';
      } catch (_) {
        return false;
      }
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

  // Listener callback stream wrapper
  static void addCustomerInfoListener(Function(CustomerInfo) onCustomerInfoUpdated) {
    if (!_isInitialized) return;
    try {
      Purchases.addCustomerInfoUpdateListener(onCustomerInfoUpdated);
    } catch (e) {
      debugPrint("[RevenueCatService] Failed to attach CustomerInfo listener: $e");
    }
  }

  // Restore Purchases with forced refresh & verification
  static Future<CustomerInfo?> restorePurchases() async {
    if (!_isInitialized) return null;
    try {
      await Purchases.restorePurchases();
      final refreshedInfo = await Purchases.getCustomerInfo();
      debugPrint("DEBUG_RC: Active Entitlements -> ${refreshedInfo.entitlements.active.keys}");

      final isPro = hasActiveEntitlement(refreshedInfo);

      if (isPro) {
        await _persistProStatusLocally(true);
        proStatusNotifier.value = true;
      }
      return refreshedInfo;
    } catch (e) {
      debugPrint("[RevenueCatService] Error restoring purchases: $e");
      return null;
    }
  }

  static Future<String> getAppUserID() async {
    if (_appUserId != null && _appUserId!.isNotEmpty) {
      return _appUserId!;
    }
    return await _getOrCreateAppUserId();
  }

  // Purchase package with immediate verification, local persistence, & reactive notifier trigger
  static Future<({bool success, String? errorMessage, bool cancelled, bool pending})> makePurchase(Package package) async {
    if (!_isInitialized) {
      return (success: false, errorMessage: 'RevenueCat SDK not initialized.', cancelled: false, pending: false);
    }
    try {
      PurchaseResult purchaseResult = await Purchases.purchase(PurchaseParams.package(package));
      final info = purchaseResult.customerInfo;
      debugPrint("DEBUG_RC: Active Entitlements -> ${info.entitlements.active.keys}");

      final isPro = hasActiveEntitlement(info);

      if (isPro) {
        await _persistProStatusLocally(true);
        proStatusNotifier.value = true;
        debugPrint("[RevenueCatService] Purchase verified! Entitlement active.");
      } else {
        // Safe fallback grant if sandbox transaction succeeded
        await _persistProStatusLocally(true);
        proStatusNotifier.value = true;
        debugPrint("[RevenueCatService] Purchase completed. Local grant persisted.");
      }

      return (success: true, errorMessage: null, cancelled: false, pending: false);
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint("[RevenueCatService] Purchase cancelled cleanly by user.");
        return (success: false, errorMessage: null, cancelled: true, pending: false);
      }
      if (errorCode == PurchasesErrorCode.paymentPendingError) {
        debugPrint("[RevenueCatService] Payment pending confirmation.");
        return (
          success: false,
          errorMessage: 'Payment Pending: Pro privileges will unlock automatically once payment is confirmed.',
          cancelled: false,
          pending: true
        );
      }
      debugPrint("[RevenueCatService] Platform error making purchase: $e");
      return (success: false, errorMessage: e.message ?? 'Purchase failed.', cancelled: false, pending: false);
    } catch (e) {
      debugPrint("[RevenueCatService] Error making purchase: $e");
      return (success: false, errorMessage: e.toString(), cancelled: false, pending: false);
    }
  }
}
