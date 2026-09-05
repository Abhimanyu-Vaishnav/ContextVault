import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'revenue_cat_service.dart';
import '../views/paywall/paywall_sheet.dart';

class OverlayService {
  /// Check whether system overlay permission is granted
  static Future<bool> isPermissionGranted() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (e) {
      debugPrint("[OverlayService] Error checking permission: $e");
      return false;
    }
  }

  /// Request system overlay permission
  static Future<bool?> requestPermission() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await FlutterOverlayWindow.requestPermission();
    } catch (e) {
      debugPrint("[OverlayService] Error requesting permission: $e");
      return false;
    }
  }

  /// Show or toggle the floating edge dock
  static Future<bool> toggleOverlay(BuildContext context) async {
    if (kIsWeb || !Platform.isAndroid) return false;

    // Check Pro entitlement status
    final isPro = await RevenueCatService.isProUser();
    if (!isPro) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚡ Floating Quick-Dock is an exclusive ContextVault Pro power feature.'),
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

    final bool isGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!isGranted) {
      await FlutterOverlayWindow.requestPermission();
      return false;
    }

    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
        return false;
      } else {
        await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          overlayTitle: "ContextVault",
          overlayContent: "Quick Access",
          flag: OverlayFlag.defaultFlag,
          visibility: NotificationVisibility.visibilitySecret,
          positionGravity: PositionGravity.right,
          height: 70,
          width: 60,
        );
        return true;
      }
    } catch (e) {
      debugPrint("[OverlayService] Error toggling overlay: $e");
      return false;
    }
  }

  /// Safely close the overlay
  static Future<void> closeOverlay() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (e) {
      debugPrint("[OverlayService] Error closing overlay: $e");
    }
  }
}
