import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'revenue_cat_service.dart';
import '../views/paywall/paywall_sheet.dart';
import '../views/quick/quick_search_dialog.dart';

class OverlayService {
  static Future<bool> isPermissionGranted() async => true;
  static Future<bool?> requestPermission() async => true;

  static Future<bool> toggleOverlay(BuildContext context) async {
    if (kIsWeb) return false;

    final isPro = await RevenueCatService.isProUser();
    if (!isPro) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚡ Quick Access Assistant is an exclusive ContextVault Pro power feature.'),
            backgroundColor: Color(0xFFD29922),
            duration: Duration(seconds: 3),
          ),
        );
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const PaywallSheet(),
        );
      }
      return false;
    }

    if (context.mounted) {
      QuickSearchDialog.show(context);
    }
    return true;
  }

  static Future<void> closeOverlay() async {}
}
