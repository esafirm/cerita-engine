import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fsse/fsse.dart';

import '../common/avatar.dart';
import '../common/choice_list.dart';
import '../common/input_prompt.dart';
import '../story_controller.dart';
import '../story_setup.dart';

/// Phone call mode: caller card, call timer, live captions and reply options.
class CallView extends StatefulWidget {
  final StoryController controller;
  final StorySetup setup;
  final VoidCallback onMenu;

  const CallView({super.key, required this.controller, required this.setup, required this.onMenu});

  @override
  State<CallView> createState() => _CallViewState();
}

class _CallViewState extends State<CallView> {
  late final Timer _ticker;
  final _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final config = widget.setup.config;
    final scene = controller.scene;
    final item = controller.current;
    final memberId = controller.channel?.members.firstOrNull;
    final caller = memberId == null ? controller.currentProfile : controller.profileById(memberId);

    // The call timer starts once the first line is spoken.
    if (item is TextItemType && !_stopwatch.isRunning) _stopwatch.start();
    final elapsed = _stopwatch.elapsed;
    final status = switch (item) {
      NarrationItemType(:final text) => text,
      _ when _stopwatch.isRunning =>
        "${elapsed.inMinutes.toString().padLeft(2, "0")}:${(elapsed.inSeconds % 60).toString().padLeft(2, "0")}",
      _ => "Calling…",
    };
    // Keep the last spoken line on screen while the player picks a reply.
    final caption = controller.history
        .lastWhere(
          (entry) => entry.conversationKey == controller.conversation?.key && entry.itemType is TextItemType,
          orElse: () => const TranscriptEntry(conversationKey: "", mode: SceneMode.call),
        )
        .itemType
        ?.getText();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: controller.advance,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (scene.background != null) Image.asset(config.bg(scene.background!), fit: BoxFit.cover),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: const Color(0xCC0B1020)),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: widget.onMenu,
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),
                _Pulse(
                  active: controller.phase == StoryPhase.typing || item is NarrationItemType,
                  child: StoryAvatar(
                    asset: caller?.avatar == null ? null : config.avatar(caller!.avatar!),
                    name: caller?.name ?? "",
                    radius: 64,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  caller?.name ?? "Unknown",
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(status, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                const Spacer(),
                if (caption != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        caption,
                        key: ValueKey(caption),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 19, height: 1.4),
                      ),
                    ),
                  ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: switch (controller.phase) {
                    StoryPhase.choice when item is ChoiceItemType =>
                      ChoiceList(key: ValueKey(item), item: item, dark: true, onSelected: controller.choose),
                    StoryPhase.input when item is InputItemType => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: InputPrompt(item: item, onSubmit: controller.submitInput),
                        ),
                      ),
                    _ => const _CallButtons(),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CallButtons extends StatelessWidget {
  const _CallButtons();

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, Color color) => CircleAvatar(
          radius: 30,
          backgroundColor: color,
          child: Icon(icon, color: Colors.white, size: 28),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        button(Icons.mic_off, Colors.white24),
        button(Icons.call_end, Colors.redAccent),
        button(Icons.volume_up, Colors.white24),
      ],
    );
  }
}

class _Pulse extends StatefulWidget {
  final bool active;
  final Widget child;

  const _Pulse({required this.active, required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _animation =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withAlpha(widget.active ? (120 * (1 - _animation.value)).round() : 40),
            width: 2 + (widget.active ? 10 * _animation.value : 0),
          ),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}
