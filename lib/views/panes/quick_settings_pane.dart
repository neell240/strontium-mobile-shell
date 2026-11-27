import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:strontianite/views/clock_editor.dart';
import 'package:strontianite/views/ytm_settings.dart';
import 'package:strontianite/utils/ambient_settings.dart';
import 'package:strontianite/handlers/alarms_handler.dart';

class QuickSettingsPane extends StatefulWidget {
  const QuickSettingsPane({super.key});

  @override
  State<QuickSettingsPane> createState() => _QuickSettingsPaneState();
}

class _QuickSettingsPaneState extends State<QuickSettingsPane> {
  static const _system = MethodChannel('strontium.mobile/system');

  bool _immersive = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _system.invokeMethod<bool>('getImmersiveMode').then((value) {
        if (mounted) setState(() => _immersive = value ?? false);
      }).catchError((Object error) {
        // An older APK may not expose the native method yet.
      });
    }
  }

  void _feedback(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Strontianite settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('Appearance & clock'),
          subtitle: const Text('Wallpapers, clock faces, layout and battery indicator'),
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ClockEditor())),
        ),
        ListTile(
          leading: const Icon(Icons.music_note_outlined),
          title: const Text('Music settings'),
          subtitle: const Text('YouTube Music configuration'),
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const YtmSettings())),
        ),
        if (Platform.isAndroid) ...[
          const Divider(),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Set Strontianite as Home'),
            subtitle: const Text('Choose Strontianite as your default Android launcher'),
            onTap: () async {
              try { await _system.invokeMethod<bool>('requestHomeRole'); }
              catch (e) { _feedback('Could not open Home selection: $e'); }
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.swipe_outlined),
            title: const Text('Immersive fullscreen'),
            subtitle: const Text('Off: use Android system Back, Home and Recents. On: hide system bars; gestures may be harder to access.'),
            value: _immersive,
            onChanged: (enabled) async {
              try {
                await _system.invokeMethod<void>('setImmersiveMode', {'enabled': enabled});
                if (mounted) setState(() => _immersive = enabled);
              } catch (e) { _feedback('Navigation setting failed: $e'); }
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_overscan_outlined),
            title: const Text('Android navigation settings'),
            subtitle: const Text('Choose system gesture navigation or 3-button navigation in Android settings'),
            onTap: () async {
              try { await _system.invokeMethod<void>('openNavigationSettings'); }
              catch (e) { _feedback('Could not open navigation settings: $e'); }
            },
          ),
          ListTile(
            leading: const Icon(Icons.bluetooth_audio_outlined),
            title: const Text('Bluetooth audio devices'),
            subtitle: const Text('Pair headphones or a speaker; Android chooses the audio route'),
            onTap: () async {
              try { await _system.invokeMethod<void>('openBluetoothSettings'); }
              catch (e) { _feedback('Could not open Bluetooth settings: $e'); }
            },
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.nights_stay_outlined),
            title: Text('Ambient clock'),
            subtitle: Text('A dark clock-only view after inactivity. This is not low-power system AOD.'),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AmbientSettings.keepAwake,
            builder: (_, enabled, __) => SwitchListTile(
              title: const Text('Keep screen awake'),
              subtitle: const Text('While Strontianite is visible; higher battery use'),
              value: enabled,
              onChanged: (value) async {
                try { await AmbientSettings.setKeepAwake(value); }
                catch (e) { _feedback('Screen setting failed: $e'); }
              },
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AmbientSettings.ambientEnabled,
            builder: (_, enabled, __) => SwitchListTile(
              title: const Text('Show ambient clock after idle'),
              value: enabled,
              onChanged: (value) => AmbientSettings.setAmbient(value),
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: AmbientSettings.idleMinutes,
            builder: (_, minutes, __) => ListTile(
              title: const Text('Ambient clock delay'),
              trailing: DropdownButton<int>(
                value: minutes,
                items: const [1, 2, 5, 10].map((n) => DropdownMenuItem(value: n, child: Text('$n min'))).toList(),
                onChanged: (value) { if (value != null) AmbientSettings.setIdleMinutes(value); },
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AmbientSettings.standbyWidgets,
            builder: (_, enabled, __) => SwitchListTile(
              secondary: const Icon(Icons.widgets_outlined),
              title: const Text('Strontium Standby widgets'),
              subtitle: const Text('Show clock, music, and next alarm while idle. Turn off for the classic ambient clock.'),
              value: enabled,
              onChanged: (value) => AmbientSettings.setStandbyWidgets(value),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.record_voice_over_outlined),
            title: const Text('Launch default assistant'),
            subtitle: const Text('Opens your Android default assistant, if installed'),
            onTap: () async {
              try {
                final launched = await _system.invokeMethod<bool>('launchAssistant') ?? false;
                if (!launched) _feedback('Set a default assistant in Android settings first.');
              } catch (e) { _feedback('Assistant unavailable: $e'); }
            },
          ),
          ListTile(
            leading: const Icon(Icons.headphones_outlined),
            title: const Text('Music app access'),
            subtitle: const Text('Allow notification listener access to show Spotify and other players'),
            onTap: () async {
              try { await _system.invokeMethod<void>('openNotificationAccess'); }
              catch (e) { _feedback('Could not open access settings: $e'); }
            },
          ),
          ListTile(
            leading: const Icon(Icons.alarm_outlined),
            title: const Text('Reliable system Clock alarm'),
            subtitle: const Text('Set a real alarm in the Android Clock app while launcher alarms are being repaired'),
            onTap: () async {
              try { await _system.invokeMethod<bool>('openSystemAlarm'); }
              catch (e) { _feedback('Clock app unavailable: $e'); }
            },
          ),
          ListTile(
            leading: const Icon(Icons.alarm_on_outlined),
            title: const Text('Test alarm sound'),
            subtitle: const Text('Play the alarm tone for three seconds to diagnose audio'),
            onTap: () async {
              try { await AlarmsHandler.testAlarmSound(); _feedback('Alarm audio test finished.'); }
              catch (e) { _feedback('Alarm audio failed: $e'); }
            },
          ),
        ],
        if (Platform.isAndroid)
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Android system settings'),
            subtitle: const Text('Network, permissions, display and installed apps'),
            onTap: () async {
              try {
                await _system.invokeMethod<void>('openSettings');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not open Android settings: $e')));
                }
              }
            },
          ),
        if (Platform.isLinux)
          const ListTile(
            leading: Icon(Icons.power_settings_new),
            title: Text('Linux power actions'),
            subtitle: Text('Power controls are available in the Linux session'),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 24),
          child: Text('Tip: You can also long-press the clock to change its appearance.'),
        ),
      ],
    );
  }
}
