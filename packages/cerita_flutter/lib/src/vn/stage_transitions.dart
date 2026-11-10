import 'dart:math';

import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/widgets.dart';

/// Builds a `STAGE` [transition] for [child] driven by [animation] (0 hidden, 1 shown).
///
/// With [keepOutgoing] the child stays as it is while [animation] runs in reverse, so in an
/// [AnimatedSwitcher] only the incoming background animates over the outgoing one (a dissolve).
/// `fade_black` still fades the outgoing child out first, then the incoming one in.
Widget stageTransition(StageTransition transition, Animation<double> animation, Widget child,
    {bool keepOutgoing = false}) {
  if (transition == StageTransition.none) return child;
  return AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final outgoing = animation.status == AnimationStatus.reverse;
      if (keepOutgoing && outgoing && transition != StageTransition.fadeBlack) return child!;
      final t = Curves.easeInOut.transform(animation.value);
      return switch (transition) {
        StageTransition.fadeBlack => Opacity(opacity: (t * 2 - 1).clamp(0.0, 1.0), child: child),
        StageTransition.slideLeft => _slide(Offset(-1 + t, 0), t, child!),
        StageTransition.slideRight => _slide(Offset(1 - t, 0), t, child!),
        StageTransition.slideUp => _slide(Offset(0, 1 - t), t, child!),
        StageTransition.zoom => Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
          ),
        StageTransition.wipeLeft || StageTransition.wipeRight => ClipRect(
            clipper: _WipeClipper(t, fromLeft: transition == StageTransition.wipeLeft),
            child: child,
          ),
        _ => Opacity(opacity: t, child: child),
      };
    },
  );
}

Widget _slide(Offset offset, double t, Widget child) => FractionalTranslation(
      translation: offset,
      child: Opacity(opacity: min(1, t * 2), child: child),
    );

/// Reveals [progress] of the width, from the left or the right edge.
class _WipeClipper extends CustomClipper<Rect> {
  final double progress;
  final bool fromLeft;

  const _WipeClipper(this.progress, {required this.fromLeft});

  @override
  Rect getClip(Size size) {
    final width = size.width * progress;
    return fromLeft
        ? Rect.fromLTWH(0, 0, width, size.height)
        : Rect.fromLTWH(size.width - width, 0, width, size.height);
  }

  @override
  bool shouldReclip(_WipeClipper oldClipper) => progress != oldClipper.progress || fromLeft != oldClipper.fromLeft;
}
