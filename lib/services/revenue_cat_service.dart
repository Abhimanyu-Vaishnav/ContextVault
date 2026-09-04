import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  // Yaha dashboard se copy ki hui Test Store public key paste karein
  static const _apiKeyAndroid = "test_rVYLVfTXpbrozVIFUsYtdsZNSha";
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  static Future<void> init() async {
    try {
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

      await Purchases.setLogLevel(LogLevel.debug);
      PurchasesConfiguration configuration = PurchasesConfiguration(
        _apiKeyAndroid,
      );
      await Purchases.configure(configuration);
      _isInitialized = true;
      debugPrint("[RevenueCatService] Initialized successfully");
    } catch (e, stack) {
      _isInitialized = false;
      debugPrint("[RevenueCatService] Initialization failed (graceful fallback): $e\n$stack");
    }
  }

  // Check if user has active Pro Entitlement
  static Future<bool> isProUser() async {
    if (!_isInitialized) return false;
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all['pro_access']?.isActive ?? false;
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

  // Purchase package
  static Future<bool> makePurchase(Package package) async {
    if (!_isInitialized) return false;
    try {
      PurchaseResult purchaseResult = await Purchases.purchase(PurchaseParams.package(package));
      return purchaseResult.customerInfo.entitlements.all['pro_access']?.isActive ?? false;
    } catch (e) {
      debugPrint("[RevenueCatService] Error making purchase: $e");
      return false;
    }
  }
}
