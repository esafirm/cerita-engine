import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Calls [onPeek] with true while the player holds a finger anywhere on [child], to look at the artwork without
/// the UI, and with false once the finger lifts. A hold that starts on a control doesn't peek: anything with a
/// [MouseRegion] counts, which every `InkWell` and Material button has. Wrap a control made of a plain
/// [GestureDetector] in a [MouseRegion] to keep it out.
class HoldToPeek extends StatefulWidget {
  final ValueChanged<bool> onPeek;
  final Widget child;

  const HoldToPeek({super.key, required this.onPeek, required this.child});

  @override
  State<HoldToPeek> createState() => _HoldToPeekState();
}

class _HoldToPeekState extends State<HoldToPeek> {
  bool _peeking = false;

  /// Whether a press at [position] (global) lands on a control inside this widget.
  bool _onControl(Offset position) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, position, View.of(context).viewId);
    final self = context.findRenderObject();
    // The path runs from the innermost hit up to the root: stop at this widget, the stage is not a control.
    for (final entry in result.path) {
      if (identical(entry.target, self)) break;
      if (entry.target is RenderMouseRegion) return true;
    }
    return false;
  }

  void _start(LongPressStartDetails details) {
    if (_onControl(details.globalPosition)) return;
    _peeking = true;
    widget.onPeek(true);
  }

  void _release() {
    if (!_peeking) return;
    _peeking = false;
    widget.onPeek(false);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onLongPressStart: _start,
    onLongPressEnd: (_) => _release(),
    onLongPressCancel: _release,
    child: widget.child,
  );
}
