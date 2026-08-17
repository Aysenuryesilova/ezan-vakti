import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeWidgetService {
  static const _channel = MethodChannel('com.aysenuryesilova.ezanvakti/widget');

  static Future<void> update({
    required String location,
    required String nextPrayer,
    required String countdown,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('widget_location', location);
    await prefs.setString('widget_next_prayer', nextPrayer);
    await prefs.setString('widget_countdown', countdown);
    try {
      await _channel.invokeMethod<void>('refreshWidget');
    } on PlatformException {
      // Home-screen widgets are currently available on Android only.
    } on MissingPluginException {
      // Home-screen widgets are currently available on Android only.
    }
  }
}
