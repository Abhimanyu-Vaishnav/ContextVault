import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'revenue_cat_service.dart';
import '../views/paywall/paywall_sheet.dart';

class OverlayService {
  /// Check whether the Android system overlay permission (SYSTEM_ALERT_WINDOW) is granted
  static Future<bool> isPermissionGranted() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (e) {
      debugPrint("[OverlayService] Error checking permission: $e");
      return false;
    }
  }

  /// Request system overlay permission from Android System Settings
  static Future<bool?> requestPermission() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await FlutterOverlayWindow.requestPermission();
    } catch (e) {
      debugPrint("[OverlayService] Error requesting permission: $e");
      return false;
    }
  }

  /// Show or toggle the floating edge bubble overlay window
  static Future<bool> toggleOverlay(BuildContext context) async {
    if (kIsWeb || !Platform.isAndroid) return false;

    // Check Pro entitlement status first
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

    // Check overlay permission
    final permissionGranted = await isPermissionGranted();
    if (!permissionGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please grant "Display over other apps" permission in Android Settings.'),
            backgroundColor: Color(0xFF58A6FF),
          ),
        );
      }
      await requestPermission();
      return false;
    }

    final isOverlayActive = await FlutterOverlayWindow.isActive();
    if (isOverlayActive) {
      await closeOverlay();
      return false;
    } else {
      await showOverlay();
      return true;
    }
  }

  /// Show the floating edge dock overlay window
  static Future<void> showOverlay() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      if (await FlutterOverlayWindow.isActive()) return;
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: "ContextVault Quick-Dock",
        overlayContent: "Tap to expand Edge Vault",
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilitySecret,
        positionGravity: PositionGravity.right,
        height: 180,
        width: 140,
      );
      debugPrint("[OverlayService] Floating Edge Dock activated.");
    } catch (e) {
      debugPrint("[OverlayService] Error showing overlay: $e");
    }
  }

  /// Close the floating overlay window
  static Future<void> closeOverlay() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
        debugPrint("[OverlayService] Floating Edge Dock closed.");
      }
    } catch (e) {
      debugPrint("[OverlayService] Error closing overlay: $e");
    }
  }
}
