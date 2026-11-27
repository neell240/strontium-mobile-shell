import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:strontianite/main.dart';
import 'package:strontianite/providers/alarms_provider.dart';

/// An awake, dark nightstand dashboard. This is NOT hardware low-power AOD.
class StrontiumStandby extends ConsumerStatefulWidget {
  const StrontiumStandby({super.key});

  @override
  ConsumerState<StrontiumStandby> createState() => _StrontiumStandbyState();
}

class _StrontiumStandbyState extends ConsumerState<StrontiumStandby> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Widget _tile({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF121A20),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF26323B)),
    ),
    padding: const EdgeInsets.all(12),
    child: Center(child: child),
  );

  @override
  Widget build(BuildContext context) {
    final alarms = ref.watch(alarmsProvider);
    final upcoming = alarms.map((a) {
      var date = DateTime(_now.year, _now.month, _now.day, a.time.hour, a.time.minute);
      if (!date.isAfter(_now)) date = date.add(const Duration(days: 1));
      return (alarm: a, date: date);
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
    final next = upcoming.isEmpty ? null : upcoming.first;
    final time = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    final date = '${_now.day}/${_now.month}/${_now.year}';

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(22),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850, maxHeight: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('STRONTIUM STANDBY', style: TextStyle(
                color: Color(0xFF8ABBB8), letterSpacing: 3, fontSize: 12)),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    _tile(child: FittedBox(fit: BoxFit.scaleDown, child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(time, style: const TextStyle(fontSize: 66, fontWeight: FontWeight.w300, color: Color(0xFFD0F4EE))),
                        Text(date, style: const TextStyle(fontSize: 18, color: Color(0xFF9AC1BF))),
                      ],
                    ))),
                    _tile(child: StreamBuilder<MediaItem?>(
                      stream: audioHandler.mediaItem,
                      builder: (context, snapshot) {
                        final song = snapshot.data;
                        return Column(mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.music_note, color: Color(0xFF8ABBB8), size: 28),
                          const SizedBox(height: 6),
                          Text(song?.title ?? 'No music playing', maxLines: 1,
                            overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                          Text(song?.artist ?? 'Start music in Strontianite', maxLines: 1,
                            overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF9AC1BF), fontSize: 12)),
                          const SizedBox(height: 6),
                          StreamBuilder<PlaybackState>(
                            stream: audioHandler.playbackState,
                            builder: (_, state) => IconButton(
                              tooltip: state.data?.playing == true ? 'Pause music' : 'Play music',
                              icon: Icon(state.data?.playing == true ? Icons.pause_circle : Icons.play_circle,
                                color: const Color(0xFFD0F4EE)),
                              onPressed: () {
                                if (state.data?.playing == true) { audioHandler.pause(); }
                                else { audioHandler.play(); }
                              },
                            ),
                          ),
                        ]);
                      },
                    )),
                    _tile(child: Column(mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.alarm, color: Color(0xFF8ABBB8), size: 30),
                      const SizedBox(height: 8),
                      const Text('Next launcher alarm', style: TextStyle(color: Color(0xFF9AC1BF), fontSize: 12)),
                      Text(next == null ? 'None saved' :
                        '${next.alarm.time.hour.toString().padLeft(2, '0')}:${next.alarm.time.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 24, color: Colors.white)),
                      const Text('Use Android Clock for critical alarms',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Color(0xFF9AC1BF))),
                    ])),
                    _tile(child: const Column(mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.bluetooth_audio, color: Color(0xFF8ABBB8), size: 30),
                      SizedBox(height: 8),
                      Text('Bluetooth audio', style: TextStyle(color: Colors.white)),
                      Text('Choose a device in Settings', textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF9AC1BF), fontSize: 12)),
                    ])),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text('Tap outside the music button to return home',
                style: TextStyle(color: Color(0xFF889A9F), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
