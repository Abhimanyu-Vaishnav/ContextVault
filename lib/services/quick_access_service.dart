import 'package:flutter/services.dart';

class QuickAccessService {
  static const MethodChannel _channel = MethodChannel('com.contextvault.app/quick_access');

  static Future<bool> startQuickAccessNotification() async {
    try {
      final bool success = await _channel.invokeMethod('startQuickAccessNotification');
      return success;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<bool> stopQuickAccessNotification() async {
    try {
      final bool success = await _channel.invokeMethod('stopQuickAccessNotification');
      return success;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
