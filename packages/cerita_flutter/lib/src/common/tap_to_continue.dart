import 'package:flutter/material.dart';

import '../l10n/story_language.dart';

/// A slowly pulsing "Tap to continue" pill, for a scene that has played out and waits for the player before the
/// next one (see `StoryController.sceneEndHeld`). It doesn't catch taps: the screen under it does.
class TapToContinue extends StatefulWidget {
  const TapToContinue({super.key});

  @override
  State<TapToContinue> createState() => _TapToContinueState();
}

class _TapToContinueState extends State<TapToContinue> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FadeTransition(
        opacity: _pulse.drive(Tween(begin: 0.55, end: 1.0)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                StoryLanguage.of(context).strings.tapToContinue,
                style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 0.3),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
