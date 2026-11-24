import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:cron/cron.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:strontianite/main.dart';
import 'package:strontianite/models/alarm_model.dart';
import 'package:strontianite/providers/alarms_provider.dart';

class AlarmsHandler {
  static final _cron = Cron();
  static final Map<String, int> _androidAlarms = {};
  static final Map<String, ScheduledTask> _linuxAlarms = {};
  static final _alarmPlayer = AudioPlayer();
  static final _controller = StreamController<String>.broadcast();
  static Stream<String> get ringEvents => _controller.stream;
  static final _portName = 'alarms_port';
  static final _alarmPort = ReceivePort();

  static void init() {
    IsolateNameServer.removePortNameMapping(_portName);
    IsolateNameServer.registerPortWithName(_alarmPort.sendPort, _portName);

    _alarmPort.listen((message) => _controller.add(message));
  }

  static Future<void> registerAlarm(AlarmModel alarm) async {
    if (_androidAlarms.containsKey(alarm.id) ||
        _linuxAlarms.containsKey(alarm.id)) {
      await unregisterAlarm(alarm.id);
    }

    if (Platform.isAndroid) {
      final id = await _androidScheduleNextDaily(alarm);
      _androidAlarms[alarm.id] = id;
    } else {
      _linuxAlarms[alarm.id] = _cron.schedule(
        Schedule.parse('${alarm.time.minute} ${alarm.time.hour} * * *'),
        () => _linuxRing(alarm),
      );
    }
  }

  static Future<int> _androidScheduleNextDaily(AlarmModel alarm) async {
    final now = DateTime.now();
    var target = DateTime(
      now.year,
      now.month,
      now.day,
      alarm.time.hour,
      alarm.time.minute,
    );
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }

    final intId = _uuidToInt(alarm.id);

    final scheduled = await AndroidAlarmManager.oneShotAt(
      target,
      intId,
      _androidRing,
      params: {'id': alarm.id},
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      allowWhileIdle: true,
    );

    if (!scheduled) {
      throw StateError('Android could not schedule the alarm');
    }

    return intId;
  }

  static Future<void> _linuxRing(AlarmModel alarm) async {
    await _ring(alarm.id);
    if (!alarm.repeat) {
      await _linuxAlarms[alarm.id]?.cancel();
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _androidRing(int id, Map<String, dynamic> params) async {
    // AlarmManager launches a separate Dart isolate: do not use the UI's
    // global ProviderContainer or its AudioPlayer instance here.
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    final alarmId = params['id'] as String?;
    if (alarmId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('alarms') ?? <String>[];
    AlarmModel? alarm;
    for (final encoded in saved) {
      final value = AlarmModel.fromJson(jsonDecode(encoded));
      if (value.id == alarmId) {
        alarm = value;
        break;
      }
    }
    if (alarm == null) return; // It was deleted before the callback ran.

    // A fresh player is required in the background isolate.
    final player = AudioPlayer();
    try {
      await player.setAsset('assets/audio/argon.ogg');
      await player.setLoopMode(LoopMode.one);
      // play() can remain pending while audio is playing; do not await it.
      unawaited(player.play());
      IsolateNameServer.lookupPortByName(_portName)?.send(alarmId);

      if (alarm.repeat) {
        await _androidScheduleNextDaily(alarm);
      }
      // Keep the background isolate alive briefly while ringing. Native
      // alarm notifications/foreground audio are still needed for reliability.
      await Future<void>.delayed(const Duration(seconds: 30));
    } catch (e) {
      debugPrint('Background alarm failed: $e');
    } finally {
      await player.dispose();
    }
  }

  // Audio playback for alarms scheduled in the Linux UI process.
  static Future<void> _ring(String id) async {
    debugPrint('Alarm ringing: $id');
    await _alarmPlayer.setAsset('assets/audio/argon.ogg');
    await _alarmPlayer.setLoopMode(LoopMode.one);
    unawaited(_alarmPlayer.play());
    IsolateNameServer.lookupPortByName(_portName)?.send(id);
  }

  static int _uuidToInt(String uuid) {
    final bytes = utf8.encode(uuid);
    int hash = 0;
    for (final b in bytes) {
      hash = (hash * 31 + b) & 0xFFFFFFFF;
    }
    return hash;
  }

  static Future<void> unregisterAlarm(String id) async {
    if (Platform.isAndroid) {
      final intId = _uuidToInt(id);
      await AndroidAlarmManager.cancel(intId);
    } else if (Platform.isLinux) {
      await _linuxAlarms.remove(id)?.cancel();
    }
  }

  /// UI-only diagnostic: does not test background scheduling.
  static Future<void> testAlarmSound() async {
    await _alarmPlayer.setAsset('assets/audio/argon.ogg');
    await _alarmPlayer.setLoopMode(LoopMode.one);
    unawaited(_alarmPlayer.play());
    await Future<void>.delayed(const Duration(seconds: 3));
    await _alarmPlayer.stop();
  }

  static Future<void> dismiss() async {
    await _alarmPlayer.stop();
  }
}
