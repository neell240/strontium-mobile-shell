import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:strontianite/views/clock_editor.dart';
import 'package:strontianite/views/ytm_settings.dart';

class QuickSettingsPane extends StatelessWidget {
  const QuickSettingsPane({super.key});

  static const _system = MethodChannel('strontium.mobile/system');

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
