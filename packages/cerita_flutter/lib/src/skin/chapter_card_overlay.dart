import 'dart:async';

import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import 'story_skin.dart';

/// Shows [StorySkin.chapterCard] over [child] whenever a conversation with a new chapter starts.
/// Taps are absorbed while the card is up, so the first line can't be skipped by accident, and
/// [holdsDialogue] tells the dialogue box to wait until the card starts fading out.
///
/// Placed inside the scene, so a scene switch mounts a new overlay. It then waits for the
/// first half of the scene transition, which belongs to the outgoing scene.
class ChapterCardOverlay extends StatefulWidget {
  final Conversation conversation;
  final Widget child;

  const ChapterCardOverlay({super.key, required this.conversation, required this.child});

  /// Whether a chapter card above [context] is pending or fully shown.
  static bool holdsDialogue(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DialogueHold>()?.notifier?.value ?? false;

  @override
  State<ChapterCardOverlay> createState() => _ChapterCardOverlayState();
}

class _ChapterCardOverlayState extends State<ChapterCardOverlay> with SingleTickerProviderStateMixin {
  /// Where the fade out starts, see [_opacity].
  static const _fadeOutStart = 0.8;

  // The duration is how long the card is readable, not decoration, so it is kept even when the
  // platform asks to reduce animations.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  )..addListener(_updateHold);

  /// Fades in over the first 20% and out over the last 20%.
  late final Animation<double> _opacity = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 20),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 20),
  ]).animate(_controller);

  final _hold = ValueNotifier(false);
  Timer? _delay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.duration == null) _show(entering: true);
  }

  @override
  void didUpdateWidget(ChapterCardOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final chapter = widget.conversation.chapter;
    if (chapter != null && chapter != oldWidget.conversation.chapter) _show();
  }

  void _show({bool entering = false}) {
    final skin = StorySkin.of(context);
    if (widget.conversation.chapter == null || skin.chapterCard(context, widget.conversation) == null) return;
    _controller.duration = skin.chapterCardDuration;
    _controller.value = 0;
    _delay?.cancel();
    _hold.value = true;
    // Wait for the page transition into the story, so the card isn't spent behind it.
    final route = ModalRoute.of(context)?.animation;
    if (route == null || route.isCompleted) {
      if (entering) {
        // Mounted by a scene switch: start once the outgoing scene is gone.
        _delay = Timer(skin.sceneTransitionDuration * 0.5, () => _controller.forward(from: 0));
      } else {
        _controller.forward(from: 0);
      }
    } else {
      void start(AnimationStatus status) {
        if (!status.isCompleted) return;
        route.removeStatusListener(start);
        if (mounted) _controller.forward(from: 0);
      }

      route.addStatusListener(start);
    }
  }

  void _updateHold() {
    if (_controller.value >= _fadeOutStart) _hold.value = false;
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card =
        widget.conversation.chapter == null ? null : StorySkin.of(context).chapterCard(context, widget.conversation);
    return Stack(
      fit: StackFit.expand,
      children: [
        _DialogueHold(notifier: _hold, child: widget.child),
        if (card != null)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              if (_controller.isCompleted) return const SizedBox.shrink();
              return AbsorbPointer(
                child: FadeTransition(opacity: _opacity, child: child),
              );
            },
            child: card,
          ),
      ],
    );
  }
}

class _DialogueHold extends InheritedNotifier<ValueNotifier<bool>> {
  const _DialogueHold({required super.notifier, required super.child});
}
