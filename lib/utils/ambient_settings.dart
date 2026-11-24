import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Launcher-only display preferences. No background wake lock is held.
class AmbientSettings {
  static const _channel = MethodChannel('strontium.mobile/system');
  static final keepAwake = ValueNotifier<bool>(false);
  static final ambientEnabled = ValueNotifier<bool>(false);
  static final idleMinutes = ValueNotifier<int>(2);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    keepAwake.value = prefs.getBool('b8_keep_awake') ?? false;
    ambientEnabled.value = prefs.getBool('b8_ambient') ?? false;
    idleMinutes.value = prefs.getInt('b8_idle_minutes') ?? 2;
    await syncKeepAwake();
  }

  static Future<void> syncKeepAwake() async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>(
        'setKeepScreenOn', {'enabled': keepAwake.value},
      );
    }
  }

  static Future<void> setKeepAwake(bool value) async {
    keepAwake.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('b8_keep_awake', value);
    await syncKeepAwake();
  }

  static Future<void> setAmbient(bool value) async {
    ambientEnabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('b8_ambient', value);
  }

  static Future<void> setIdleMinutes(int minutes) async {
    idleMinutes.value = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('b8_idle_minutes', minutes);
  }
}
