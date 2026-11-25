import 'dart:ui' show lerpDouble;

import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../common/motion.dart';
import '../skin/story_skin.dart';
import 'stage_transitions.dart';

/// A CG held over the stage by the `cg` stage action ([CgAction]), with its camera: [zoom] towards [focus].
///
/// A new image cross-fades over the one shown, both under the same camera, so a variant lines up with the image it
/// replaces. A `cg_move` ([CgMoveAction]) in [direction] eases the camera to the new [zoom] / [focus] over its
/// duration and keeps going while the story moves on. A CG that appears with a move starts from the framing its
/// `cg` action gave, so `cg x focus=left` and `cg_move focus=right` in one stage direction pan across the image.
class CgLayer extends StatefulWidget {
  /// Asset path. Null shows nothing.
  final String? image;
  final double zoom;
  final CgFocus focus;

  /// The `STAGE` item being played. Its `cg` transition and `cg_move` are used for the changes it makes.
  final StageItemType? direction;

  /// Applies every change without animating, e.g. while skipping.
  final bool instant;

  const CgLayer({
    super.key,
    required this.image,
    this.zoom = 1,
    this.focus = CgFocus.center,
    this.direction,
    this.instant = false,
  });

  @override
  State<CgLayer> createState() => _CgLayerState();
}

typedef _Camera = ({double zoom, Alignment focus});

class _CgLayerState extends State<CgLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _move = AnimationController(vsync: this);
  late _Camera _from = _target;
  late _Camera _to = _target;

  static Alignment _align(CgFocus focus) => Alignment(focus.x, focus.y);

  _Camera get _target => (zoom: widget.zoom, focus: _align(widget.focus));

  _Camera get _camera {
    final t = Curves.easeInOut.transform(_move.value);
    return (zoom: lerpDouble(_from.zoom, _to.zoom, t)!, focus: Alignment.lerp(_from.focus, _to.focus, t)!);
  }

  CgAction? get _shown => widget.direction?.actions.whereType<CgAction>().where((a) => a.image != null).lastOrNull;

  CgMoveAction? get _moveAction => widget.direction?.actions.whereType<CgMoveAction>().lastOrNull;

  @override
  void initState() {
    super.initState();
    _move.value = 1;
    if (widget.image != null) _aim(appeared: true);
  }

  @override
  void didUpdateWidget(CgLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // While the CG leaves, it keeps its camera.
    if (widget.image == null) return;
    final appeared = oldWidget.image == null;
    if (appeared || _target != _to || !identical(widget.direction, oldWidget.direction)) _aim(appeared: appeared);
  }

  /// Points the camera at the target: at once, or with a `cg_move` from the current framing, or from the framing the
  /// CG [appeared] with.
  void _aim({required bool appeared}) {
    final move = _moveAction;
    final target = _target;
    // With reduced motion the camera cuts to its framing instead of panning.
    if (widget.instant || reduceMotion || move == null || move.durationMs <= 0) {
      // A move from an earlier direction plays on unless the camera has somewhere else to be.
      if (target == _to && !appeared) return;
      _from = _to = target;
      _move.value = 1;
      return;
    }
    if (target == _to && !appeared) return;
    final shown = _shown;
    _from = appeared
        ? (zoom: shown?.zoom ?? 1, focus: _align(shown?.focus ?? CgFocus.center))
        : _camera;
    _to = target;
    _move
      ..duration = Duration(milliseconds: move.durationMs)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = StorySkin.of(context);
    final shown = widget.direction?.actions.whereType<CgAction>().lastOrNull;
    final transition = shown?.transition;
    final duration = widget.instant
        ? Duration.zero
        : shown == null
            ? skin.backgroundTransitionDuration
            : Duration(milliseconds: shown.durationMs);
    // A swap keeps the outgoing image under the incoming one. Hiding fades it out.
    final keepOutgoing = widget.image != null;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _move,
        builder: (context, child) {
          final camera = _camera;
          return ClipRect(
            child: Transform.scale(scale: camera.zoom, alignment: camera.focus, child: _Framed(camera.focus, child!)),
          );
        },
        child: AnimatedSwitcher(
          duration: duration,
          transitionBuilder: (child, animation) => transition == null
              ? skin.backgroundTransition(animation, child)
              : stageTransition(transition, animation, child, keepOutgoing: keepOutgoing),
          layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
          child: widget.image == null
              ? const SizedBox.expand(key: ValueKey("no-cg"))
              : _CgImage(widget.image!, key: ValueKey(widget.image)),
        ),
      ),
    );
  }
}

/// Hands the camera's focus down to every [_CgImage] under it, so the crop follows the pan.
class _Framed extends InheritedWidget {
  final Alignment focus;

  const _Framed(this.focus, Widget child) : super(child: child);

  static Alignment of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Framed>()?.focus ?? Alignment.center;

  @override
  bool updateShouldNotify(_Framed oldWidget) => focus != oldWidget.focus;
}

/// The CG covering the screen. On a screen narrower than the image, the focus picks which part of it shows.
class _CgImage extends StatelessWidget {
  final String path;

  const _CgImage(this.path, {super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.black,
        child: Image.asset(path, fit: BoxFit.cover, alignment: _Framed.of(context), gaplessPlayback: true),
      );
}
