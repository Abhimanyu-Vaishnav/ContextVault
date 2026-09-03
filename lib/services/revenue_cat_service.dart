import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  // Yaha dashboard se copy ki hui Test Store public key paste karein
  static const _apiKeyAndroid = "test_rVYLVfTXpbrozVIFUsYtdsZNSha";

  static Future<void> init() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    await Purchases.setLogLevel(LogLevel.debug);
    PurchasesConfiguration configuration = PurchasesConfiguration(
      _apiKeyAndroid,
    );
    await Purchases.configure(configuration);
  }

  // Check if user has active Pro Entitlement
  static Future<bool> isProUser() async {
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all['pro_access']?.isActive ?? false;
    } catch (e) {
      return false; // Default fallback to free tier
    }
  }

  // Fetch available paywall packages
  static Future<List<Package>> getOfferings() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null &&
          offerings.current!.availablePackages.isNotEmpty) {
        return offerings.current!.availablePackages;
      }
    } catch (e) {
      debugPrint("Error fetching offerings: $e");
    }
    return [];
  }

  // Purchase package
  static Future<bool> makePurchase(Package package) async {
    try {
      PurchaseResult purchaseResult = await Purchases.purchasePackage(package);
      return purchaseResult.customerInfo.entitlements.all['pro_access']?.isActive ?? false;
    } catch (e) {
      return false;
    }
  }
}
