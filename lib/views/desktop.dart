import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:strontianite/handlers/alarms_handler.dart';
import 'package:strontianite/main.dart';
import 'package:strontianite/providers/alarms_provider.dart';
import 'package:strontianite/views/alarm_ringing.dart';
import 'package:strontianite/views/panel.dart';
import 'package:strontianite/utils/ambient_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strontianite/views/clock.dart';
import 'package:strontianite/providers/clock_type_provider.dart';
import 'package:strontianite/views/panes/alarms_pane.dart';
import 'package:strontianite/views/panes/clock_pane.dart';
import 'package:strontianite/views/panes/launchpad_pane.dart';
import 'package:strontianite/views/panes/market_pane.dart';
import 'package:strontianite/views/panes/media_pane.dart';
import 'package:strontianite/views/panes/quick_settings_pane.dart';
import 'package:strontianite/views/panes/ytm_pane.dart';

class Desktop extends StatefulWidget {
  const Desktop({super.key});

  @override
  State<Desktop> createState() => _DesktopState();
}

class _DesktopState extends State<Desktop> {
  final List<Widget> _panels = [
    ClockPane(),
    MediaPane(),
    AlarmsPane(),
    YtmPane(),
    LaunchpadPane(),
    MarketPane(),
    QuickSettingsPane(),
  ];
  late PageController _pageController;
  Timer? _idleTimer;
  Timer? _ambientTick;
  DateTime _lastInteraction = DateTime.now();
  bool _ambient = false;
  int _ambientShift = 0;

  void _markInteraction() {
    _lastInteraction = DateTime.now();
    if (_ambient && mounted) setState(() => _ambient = false);
  }

  void _checkIdle() {
    if (!mounted || !AmbientSettings.ambientEnabled.value) {
      if (_ambient && mounted) setState(() => _ambient = false);
      return;
    }
    final idle = DateTime.now().difference(_lastInteraction);
    if (!_ambient && idle >= Duration(minutes: AmbientSettings.idleMinutes.value)) {
      setState(() => _ambient = true);
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _idleTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkIdle());
    _ambientTick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _ambient) setState(() => _ambientShift = (_ambientShift + 1) % 5);
    });
    AlarmsHandler.ringEvents.listen((id) {
      final alarm = container.read(alarmsProvider.notifier).getAlarm(id);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AlarmRinging(alarm: alarm)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _markInteraction(),
      child: Stack(children: [
        Row(
      children: [
        Panel(
          switchPane: (i) {
            setState(() {
              _markInteraction();
              _pageController.jumpToPage(i);
            });
          },
        ),
        Expanded(
          child: PageView(controller: _pageController, children: _panels),
        ),
      ],
    ),
    if (_ambient)
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _markInteraction,
          child: Container(
            color: const Color(0xFF000000),
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset((_ambientShift - 2) * 6.0, (_ambientShift - 2) * 4.0),
              child: FractionallySizedBox(
                widthFactor: 0.7,
                heightFactor: 0.7,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(primary: Color(0xFF999999), onSurface: Color(0xFF999999)),
                    ),
                    child: Consumer(builder: (context, ref, _) =>
                      Clock(clockType: ref.watch(clockTypeProvider))),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      ]),
    );
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _ambientTick?.cancel();
    _pageController.dispose();
    super.dispose();
  }
}
