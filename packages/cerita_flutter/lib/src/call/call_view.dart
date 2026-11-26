import 'dart:async';
import 'dart:ui';

import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../clues/case_board.dart';
import '../common/avatar.dart';
import '../common/choice_list.dart';
import '../common/input_prompt.dart';
import '../common/motion.dart';
import '../common/tagged_text.dart';
import '../common/tap_to_continue.dart';
import '../l10n/story_language.dart';
import '../skin/story_skin.dart';
import '../story_controller.dart';
import '../story_setup.dart';

/// Phone call mode, laid out like a phone's call screen: caller card, call timer, live captions and reply
/// options. A `ring=` scene rings until the player answers. Mute, speaker, keypad and hold work like on a phone.
/// Ending the call goes where the scene's `hangup` leads, or shows what the player's character thinks of hanging
/// up when the call can't be ended (see [StoryController.endCall]).
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
  bool _muted = false;
  bool _speaker = false;
  bool _keypad = false;
  String _digits = "";

  StoryController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      // A ringing phone vibrates every other second.
      if (controller.callState == CallState.ringing && timer.tick.isEven) HapticFeedback.vibrate();
      if (controller.callState == CallState.connected && _stopwatch.isRunning && !controller.onHold) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  void _press(VoidCallback action) {
    HapticFeedback.lightImpact();
    setState(action);
  }

  void _dial(String key) {
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
    // A long run of tones only keeps its end, like the phone's own keypad field.
    setState(() => _digits = "$_digits$key".characters.takeLast(14).toString());
  }

  void _end() {
    HapticFeedback.mediumImpact();
    setState(() {
      _keypad = false;
      _digits = "";
    });
    controller.endCall();
  }

  void _answer() {
    HapticFeedback.mediumImpact();
    controller.answerCall();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.setup.config;
    final scene = controller.scene;
    final item = controller.current;
    final memberId = controller.channel?.members.firstOrNull;
    final strings = StoryLanguage.of(context).strings;
    Profile? caller = memberId == null ? null : controller.profileById(memberId);
    if (caller == null) {
      final current = controller.currentProfile;
      if (current != null && !current.isPlayer) {
        caller = current;
      } else {
        for (final entry in controller.history.reversed) {
          if (entry.conversationKey != controller.conversation?.key) continue;
          final entryItem = controller.itemOf(entry);
          final profile = entryItem == null ? null : controller.profileOf(entryItem);
          if (profile != null && !profile.isPlayer) {
            caller = profile;
            break;
          }
        }
      }
    }
    final state = controller.callState;
    final connected = state == CallState.connected;

    // The call timer starts once the first line is spoken, and starts over when a cut call is picked up again.
    if (!connected) {
      _stopwatch
        ..stop()
        ..reset();
    } else if (item is TextItemType && !_stopwatch.isRunning) {
      _stopwatch.start();
    }
    final elapsed = _stopwatch.elapsed;
    final narrationStatus = connected && !controller.onHold && item is NarrationItemType ? item.text : null;
    final status = switch (item) {
      _ when state == CallState.ringing => strings.incomingCall,
      _ when state == CallState.ended => strings.callEnded,
      _ when controller.onHold => strings.onHold,
      NarrationItemType(:final text) => text,
      _ when _stopwatch.isRunning =>
        "${elapsed.inMinutes.toString().padLeft(2, "0")}:${(elapsed.inSeconds % 60).toString().padLeft(2, "0")}",
      _ => strings.calling,
    };
    // Keep the last spoken line on screen while the player picks a reply.
    final spoken = controller.history.lastWhere(
      (entry) => entry.conversationKey == controller.conversation?.key && controller.itemOf(entry) is TextItemType,
      orElse: () => const TranscriptEntry(conversationKey: "", mode: SceneMode.call),
    );
    final caption = connected ? controller.itemOf(spoken)?.getText() : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: controller.advance,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (scene.background != null)
                  Image.asset(
                    config.bg(scene.background!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(color: const Color(0xCC0B1020)),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    tooltip: strings.menu,
                    onPressed: widget.onMenu,
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),
                _Pulse(
                  active:
                      state == CallState.ringing ||
                      (connected && (controller.phase == StoryPhase.typing || item is NarrationItemType)),
                  child: StoryAvatar(
                    asset: caller?.avatar == null ? null : config.avatar(caller!.avatar!),
                    name: caller?.name ?? "",
                    radius: 64,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  caller?.name ?? strings.unknownCaller,
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_muted && connected) ...[
                      const Icon(Icons.mic_off, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: narrationStatus != null
                          ? TaggedText(narrationStatus, style: const TextStyle(color: Colors.white70, fontSize: 16))
                          : Text(status, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    ),
                  ],
                ),
                const Spacer(),
                if (caption != null && !_keypad)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: TaggedText(
                        caption,
                        key: ValueKey(caption),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: controller.onHold ? Colors.white38 : Colors.white,
                          fontSize: 19,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: switch (controller.refusal) {
                    final thought? => Padding(
                      key: ValueKey(thought),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _Thought(thought),
                    ),
                    null when controller.sceneEndHeld => const TapToContinue(),
                    null => const SizedBox.shrink(),
                  },
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
                  child: switch (controller.phase) {
                    _ when state == CallState.ringing => _RingingButtons(
                      strings: (answer: strings.answer, decline: strings.decline),
                      onAnswer: _answer,
                      onDecline: _end,
                    ),
                    // Hung up: the story goes on where the call leads.
                    _ when state == CallState.ended => const SizedBox(height: 172),
                    StoryPhase.choice when item is EvidenceItemType => SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.55,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: EvidencePicker(
                          key: ValueKey(item),
                          controller: controller,
                          item: item,
                          paused: controller.storyHeld || controller.onHold,
                        ),
                      ),
                    ),
                    StoryPhase.choice when item is ChoiceItemType => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (item.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TaggedText(
                              item.text,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 15),
                            ),
                          ),
                        ChoiceList(
                          key: ValueKey(item),
                          item: item,
                          dark: true,
                          paused: controller.storyHeld || controller.onHold,
                          onSelected: controller.choose,
                        ),
                      ],
                    ),
                    StoryPhase.input when item is InputItemType => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: InputPrompt(key: ValueKey(item), item: item, onSubmit: controller.submitInput),
                      ),
                    ),
                    _ => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_keypad)
                          _Keypad(digits: _digits, onKey: _dial)
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _CallButton(
                                icon: _muted ? Icons.mic_off : Icons.mic_none,
                                label: strings.mute,
                                active: _muted,
                                onTap: () => _press(() => _muted = !_muted),
                              ),
                              _CallButton(
                                icon: Icons.volume_up,
                                label: strings.speaker,
                                active: _speaker,
                                onTap: () => _press(() => _speaker = !_speaker),
                              ),
                              _CallButton(
                                icon: Icons.dialpad,
                                label: strings.keypad,
                                onTap: () => _press(() => _keypad = true),
                              ),
                              _CallButton(
                                icon: Icons.pause,
                                label: strings.hold,
                                active: controller.onHold,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  controller.holdCall(!controller.onHold);
                                },
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(child: SizedBox()),
                            _CallButton(
                              icon: Icons.call_end,
                              color: Colors.redAccent,
                              semanticLabel: strings.endCall,
                              onTap: _end,
                            ),
                            Expanded(
                              child: _keypad
                                  ? TextButton(
                                      onPressed: () => _press(() => _keypad = false),
                                      child: Text(strings.hideKeypad, style: const TextStyle(color: Colors.white)),
                                    )
                                  : const SizedBox(),
                            ),
                          ],
                        ),
                      ],
                    ),
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

/// A round call screen button with an optional label under it. An [active] toggle turns white.
class _CallButton extends StatelessWidget {
  final IconData icon;
  final String? label;

  /// What a screen reader calls a button without a [label].
  final String? semanticLabel;
  final bool active;
  final Color? color;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.onTap,
    this.label,
    this.semanticLabel,
    this.active = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final background = color ?? (active ? Colors.white : Colors.white24);
    // The label takes taps too, so a finger a little low doesn't miss the button. A screen reader reads it as one
    // button, selected while on.
    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: background,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox.square(
                dimension: 64,
                child: Icon(icon, color: active && color == null ? Colors.black87 : Colors.white, size: 28),
              ),
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 8),
            Text(label!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ],
      ),
    );
    return MergeSemantics(
      child: Semantics(
        button: true,
        label: label == null ? semanticLabel : null,
        selected: active ? true : null,
        child: button,
      ),
    );
  }
}

/// Decline and answer, the answer button nudging like a phone asking to be picked up.
class _RingingButtons extends StatefulWidget {
  final ({String answer, String decline}) strings;
  final VoidCallback onAnswer;
  final VoidCallback onDecline;

  const _RingingButtons({required this.strings, required this.onAnswer, required this.onDecline});

  @override
  State<_RingingButtons> createState() => _RingingButtonsState();
}

class _RingingButtonsState extends State<_RingingButtons> with SingleTickerProviderStateMixin {
  late final AnimationController _nudge = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat();

  @override
  void dispose() {
    _nudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CallButton(
            icon: Icons.call_end,
            label: widget.strings.decline,
            color: Colors.redAccent,
            onTap: widget.onDecline,
          ),
          AnimatedBuilder(
            animation: _nudge,
            // A hop in the first third of each beat, then still.
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -10 * Curves.easeOut.transform((1 - (_nudge.value * 3 - 1).abs()).clamp(0, 1))),
              child: child,
            ),
            child: _CallButton(
              icon: Icons.call,
              label: widget.strings.answer,
              color: Colors.green,
              onTap: widget.onAnswer,
            ),
          ),
        ],
      ),
    );
  }
}

/// The in-call keypad: tones only, like on a real call.
class _Keypad extends StatelessWidget {
  static const _keys = [
    ("1", ""),
    ("2", "ABC"),
    ("3", "DEF"),
    ("4", "GHI"),
    ("5", "JKL"),
    ("6", "MNO"),
    ("7", "PQRS"),
    ("8", "TUV"),
    ("9", "WXYZ"),
    ("*", ""),
    ("0", "+"),
    ("#", ""),
  ];

  final String digits;
  final ValueChanged<String> onKey;

  const _Keypad({required this.digits, required this.onKey});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 36,
          child: Text(digits, style: const TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 2)),
        ),
        const SizedBox(height: 8),
        for (var row = 0; row < 4; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final (key, letters) in _keys.skip(row * 3).take(3))
                  Material(
                    color: Colors.white12,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onKey(key),
                      child: SizedBox.square(
                        dimension: 64,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(key, style: const TextStyle(color: Colors.white, fontSize: 26, height: 1.1)),
                            if (letters.isNotEmpty)
                              Text(
                                letters,
                                style: const TextStyle(color: Colors.white60, fontSize: 9, letterSpacing: 1.5),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
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
  AnimationController? _animation;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Pulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  void _sync() {
    if (widget.active && !reduceMotion) {
      final controller = _animation ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
      if (!controller.isAnimating) controller.repeat();
    } else {
      _animation?.stop();
    }
  }

  @override
  void dispose() {
    _animation?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = _animation;
    Widget ring(double value) {
      final width = 2.0 + (widget.active && !reduceMotion ? 10.0 * value : 0.0);
      // Keep the outer box size constant so pulsing never triggers full-screen relayout.
      return Padding(
        padding: EdgeInsets.all(12 - width),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withAlpha(widget.active ? (120 * (1 - value)).round() : 40),
              width: width,
            ),
          ),
          child: Padding(padding: const EdgeInsets.all(10), child: widget.child),
        ),
      );
    }

    if (!widget.active || animation == null || reduceMotion) return RepaintBoundary(child: ring(0));
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) => ring(animation.value),
      ),
    );
  }
}

/// What the player's character thinks, in their own voice: why they won't hang up. Narration, so no name.
class _Thought extends StatelessWidget {
  final String text;

  const _Thought(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: TaggedText(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1.4,
        ).merge(StorySkin.of(context).narrationStyle),
      ),
    );
  }
}
