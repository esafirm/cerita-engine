import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import 'skin/story_skin.dart';

/// Plays [StorySkin.sceneTransition] whenever [scene] changes. [mode] picks the transition.
class SceneSwitcher extends StatelessWidget {
  /// Identity of the shown scene. A different value switches scenes, an equal one updates in place.
  final Object scene;
  final SceneMode mode;
  final Widget child;

  const SceneSwitcher({super.key, required this.scene, required this.mode, required this.child});

  @override
  Widget build(BuildContext context) {
    final skin = StorySkin.of(context);
    return AnimatedSwitcher(
      duration: skin.sceneTransitionDuration,
      transitionBuilder: (child, animation) => skin.sceneTransition(
        (child.key as ValueKey<(Object, SceneMode)>).value.$2,
        animation,
        _FreezeOnExit(animation: animation, child: child),
      ),
      // The outgoing scene must not catch taps meant for the incoming one. Every child keeps the
      // same keyed wrapper, so the outgoing scene keeps its state: re-parenting it would rebuild
      // it from the story state, which already holds the incoming scene.
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [
          for (final child in [...previous, ?current])
            IgnorePointer(key: child.key, ignoring: child != current, child: child),
        ],
      ),
      child: KeyedSubtree(key: ValueKey<(Object, SceneMode)>((scene, mode)), child: child),
    );
  }
}

/// Shows its child as it last looked once [animation] runs in reverse, that is once the scene is on its way out.
///
/// The views read the story state as it is now, which already holds the incoming scene. Anything that rebuilds
/// the outgoing view while it fades (a call timer, a typing line, a language switch) would draw the next scene's
/// background, speaker or caption in it for a moment.
class _FreezeOnExit extends StatefulWidget {
  final Animation<double> animation;
  final Widget child;

  const _FreezeOnExit({required this.animation, required this.child});

  @override
  State<_FreezeOnExit> createState() => _FreezeOnExitState();
}

class _FreezeOnExitState extends State<_FreezeOnExit> {
  final _snapshot = SnapshotController();

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(_FreezeOnExit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation == widget.animation) return;
    oldWidget.animation.removeStatusListener(_onStatus);
    widget.animation.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    _snapshot.allowSnapshotting = status == AnimationStatus.reverse || status == AnimationStatus.dismissed;
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    _snapshot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      // Permissive: a platform view (a video) can't be captured, so it keeps playing live instead.
      SnapshotWidget(controller: _snapshot, mode: SnapshotMode.permissive, child: widget.child);
}
