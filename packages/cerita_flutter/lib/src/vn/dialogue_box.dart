import 'package:flutter/material.dart';

import '../skin/chapter_card_overlay.dart';
import '../skin/story_skin.dart';

/// Bottom dialogue box with typewriter text, drawn by [StorySkin.dialogueFrame].
/// [complete] finishes the animation; it returns false if it was already done.
class DialogueBox extends StatefulWidget {
  final String text;
  final String? speaker;
  final bool italic;

  /// Skips the typewriter animation (skip mode, restored lines).
  final bool instant;

  /// Called once [text] is fully shown, typed out or completed by a tap.
  final VoidCallback? onTyped;

  const DialogueBox(
    this.text, {
    super.key,
    this.speaker,
    this.italic = false,
    this.instant = false,
    this.onTyped,
  });

  @override
  State<DialogueBox> createState() => DialogueBoxState();
}

class DialogueBoxState extends State<DialogueBox> with SingleTickerProviderStateMixin {
  static const _msPerChar = 40;

  late final AnimationController _typewriter = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status.isCompleted) _typed();
    });

  /// A chapter card is up: the box stays hidden and the line waits for it.
  bool _held = false;
  bool _pending = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _held = ChapterCardOverlay.holdsDialogue(context);
    if (!_held && _pending) _start();
  }

  @override
  void didUpdateWidget(DialogueBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text) {
      // The same line again: no new animation, so report it as shown right away.
      if (_typewriter.isCompleted) _typed();
      return;
    }
    _pending = true;
    if (!_held) _start();
  }

  void _start() {
    _pending = false;
    _typewriter.duration = Duration(milliseconds: widget.text.characters.length * _msPerChar);
    if (widget.instant) {
      final wasCompleted = _typewriter.isCompleted;
      _typewriter.value = 1;
      if (wasCompleted) _typed();
    } else {
      _typewriter.forward(from: 0);
    }
  }

  /// Runs after the frame: the line can be shown during a build, and the listener rebuilds its parent.
  void _typed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onTyped?.call();
    });
  }

  bool get isTyping => _typewriter.isAnimating;

  bool complete() {
    if (!isTyping) return false;
    _typewriter.value = 1;
    return true;
  }

  @override
  void dispose() {
    _typewriter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final characters = widget.text.characters;
    final box = AnimatedBuilder(
      animation: _typewriter,
      builder: (context, _) {
        final visible = (characters.length * _typewriter.value).round();
        return StorySkin.of(context).dialogueFrame(
          context,
          DialogueFrame(
            speaker: widget.speaker,
            done: _typewriter.value == 1,
            body: Text(
              characters.take(visible).toString(),
              style: TextStyle(fontStyle: widget.italic ? FontStyle.italic : null),
            ),
          ),
        );
      },
    );
    return AnimatedOpacity(opacity: _held ? 0 : 1, duration: const Duration(milliseconds: 250), child: box);
  }
}
