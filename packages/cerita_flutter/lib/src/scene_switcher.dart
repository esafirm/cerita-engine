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
      transitionBuilder: (child, animation) =>
          skin.sceneTransition((child.key as ValueKey<(Object, SceneMode)>).value.$2, animation, child),
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
