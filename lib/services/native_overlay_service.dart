import 'package:flutter/services.dart';

class NativeOverlayService {
  static const _channel = MethodChannel('com.contextvault.app/overlay');

  static Future<bool> checkPermission() async {
    try {
      final bool? result = await _channel.invokeMethod('checkPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> startBubble() async {
    try {
      final bool? result = await _channel.invokeMethod('startBubble');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> stopBubble() async {
    try {
      final bool? result = await _channel.invokeMethod('stopBubble');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
