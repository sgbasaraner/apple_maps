
import 'dart:async';

import 'package:flutter/services.dart';

class AppleMaps {
  static const MethodChannel _channel =
      const MethodChannel('apple_maps');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
