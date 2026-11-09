import 'package:flutter/material.dart';

/// Bottom dialogue box with a speaker nameplate and typewriter text.
/// [complete] finishes the animation; it returns false if it was already done.
class DialogueBox extends StatefulWidget {
  final String text;
  final String? speaker;
  final bool italic;

  /// Skips the typewriter animation (skip mode, restored lines).
  final bool instant;

  const DialogueBox(this.text, {super.key, this.speaker, this.italic = false, this.instant = false});

  @override
  State<DialogueBox> createState() => DialogueBoxState();
}

class DialogueBoxState extends State<DialogueBox> with SingleTickerProviderStateMixin {
  static const _msPerChar = 28;

  late final AnimationController _typewriter = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(DialogueBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _start();
  }

  void _start() {
    _typewriter.duration = Duration(milliseconds: widget.text.characters.length * _msPerChar);
    if (widget.instant) {
      _typewriter.value = 1;
    } else {
      _typewriter.forward(from: 0);
    }
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
    final scheme = Theme.of(context).colorScheme;
    final characters = widget.text.characters;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 110),
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(225),
            border: Border.all(color: scheme.primary, width: 2),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
          ),
          child: AnimatedBuilder(
            animation: _typewriter,
            builder: (context, _) {
              final visible = (characters.length * _typewriter.value).round();
              return Text(
                characters.take(visible).toString(),
                style: TextStyle(
                  fontSize: 17,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                  fontStyle: widget.italic ? FontStyle.italic : null,
                ),
              );
            },
          ),
        ),
        if (widget.speaker != null)
          Positioned(
            left: 14,
            top: -16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(16)),
              child: Text(
                widget.speaker!,
                style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
