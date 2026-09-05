import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'revenue_cat_service.dart';
import 'native_overlay_service.dart';
import '../views/paywall/paywall_sheet.dart';

class OverlayService {
  static bool _isBubbleRunning = false;

  static Future<bool> isPermissionGranted() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    return await NativeOverlayService.checkPermission();
  }

  static Future<bool> toggleOverlay(BuildContext context) async {
    if (kIsWeb || !Platform.isAndroid) return false;

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

    if (_isBubbleRunning) {
      await NativeOverlayService.stopBubble();
      _isBubbleRunning = false;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Floating Edge Assistant stopped.'),
            backgroundColor: Color(0xFF21262D),
          ),
        );
      }
      return false;
    } else {
      final started = await NativeOverlayService.startBubble();
      if (started) {
        _isBubbleRunning = true;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚡ Floating Edge Assistant active on screen!'),
              backgroundColor: Color(0xFF238636),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please grant "Display over other apps" permission in Android Settings.'),
              backgroundColor: Color(0xFFD29922),
            ),
          );
        }
      }
      return started;
    }
  }

  static Future<void> closeOverlay() async {
    await NativeOverlayService.stopBubble();
    _isBubbleRunning = false;
  }
}
