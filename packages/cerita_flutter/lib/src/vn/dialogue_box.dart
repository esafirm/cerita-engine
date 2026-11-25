import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../common/tagged_text.dart';
import '../l10n/story_language.dart';
import '../skin/chapter_card_overlay.dart';
import '../skin/story_skin.dart';

/// Bottom dialogue box with typewriter text and text tags, drawn by [StorySkin.dialogueFrame].
/// [complete] finishes the animation or continues after a `{w}`; it returns false if the line was already shown.
class DialogueBox extends StatefulWidget {
  final String text;
  final String? speaker;
  final bool italic;

  /// Skips the typewriter animation (skip mode, restored lines).
  final bool instant;

  /// Typewriter speed. 0 shows the line at once.
  final int msPerChar;

  /// Continues after a `{w}` by itself after this long (auto mode).
  final Duration? autoResume;

  /// Called once [text] is fully shown, typed out or completed by a tap.
  final VoidCallback? onTyped;

  const DialogueBox(
    this.text, {
    super.key,
    this.speaker,
    this.italic = false,
    this.instant = false,
    this.msPerChar = 40,
    this.autoResume,
    this.onTyped,
  });

  @override
  State<DialogueBox> createState() => DialogueBoxState();
}

class DialogueBoxState extends State<DialogueBox> {
  final _typewriter = GlobalKey<TypewriterTextState>();

  bool complete() => _typewriter.currentState?.complete() ?? false;

  /// The text shown so far.
  String get visibleText => _typewriter.currentState?.visibleText ?? "";

  @override
  Widget build(BuildContext context) {
    // A chapter card is up: the box stays hidden and the line waits for it.
    final held = ChapterCardOverlay.holdsDialogue(context);
    final name = widget.speaker ?? StoryLanguage.of(context).strings.dialogue;
    // A screen reader reads the whole line once, with who says it, not each letter as it types.
    final box = AnimatedOpacity(
      opacity: held ? 0 : 1,
      duration: const Duration(milliseconds: 250),
      child: TypewriterText(
        widget.text,
        key: _typewriter,
        style: widget.italic ? StorySkin.of(context).narrationStyle : null,
        instant: widget.instant,
        msPerChar: widget.msPerChar,
        autoResume: widget.autoResume,
        onTyped: widget.onTyped,
        builder: (context, text, done) => StorySkin.of(context).dialogueFrame(
          context,
          DialogueFrame(speaker: widget.speaker, done: done, body: text),
        ),
      ),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: "$name: ${TextMarkup.plain(widget.text)}",
      excludeSemantics: true,
      child: box,
    );
  }
}
