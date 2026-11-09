import 'package:flutter/material.dart';
import 'package:fsse/fsse.dart';

/// [Poi] handles the background and up to three character sprite slots.
/// The active speaker is full opacity and slightly larger; others are dimmed.
class Poi extends StatelessWidget {
  final String? background;
  final Map<SpritePosition, String> sprites;
  final SpritePosition? speaker;

  const Poi({super.key, this.background, this.sprites = const {}, this.speaker});

  static const _alignments = {
    SpritePosition.left: Alignment(-1.3, 1),
    SpritePosition.center: Alignment(0, 1),
    SpritePosition.right: Alignment(1.3, 1),
  };

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 700),
          layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
          child: background == null
              ? Container(key: const ValueKey("no-bg"), color: Colors.black)
              : Image.asset(background!, key: ValueKey(background), fit: BoxFit.cover, gaplessPlayback: true),
        ),
        // The speaker is painted last so it overlaps its neighbours.
        for (final position in [...SpritePosition.values.where((p) => p != speaker), ?speaker])
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            alignment: _alignments[position]!,
            child: FractionallySizedBox(
              heightFactor: sprites.length > 2 ? 0.66 : 0.82,
              child: _SpriteSlot(sprite: sprites[position], active: speaker == null || speaker == position),
            ),
          ),
      ],
    );
  }
}

class _SpriteSlot extends StatelessWidget {
  final String? sprite;
  final bool active;

  const _SpriteSlot({required this.sprite, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: active ? 1.04 : 0.97,
      alignment: Alignment.bottomCenter,
      duration: const Duration(milliseconds: 250),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: sprite == null
            ? const SizedBox.shrink(key: ValueKey("empty"))
            : TweenAnimationBuilder<double>(
                key: ValueKey(sprite),
                tween: Tween(end: active ? 0 : 0.45),
                duration: const Duration(milliseconds: 250),
                builder: (context, dim, child) => ColorFiltered(
                  colorFilter: ColorFilter.mode(Colors.black.withAlpha((dim * 255).round()), BlendMode.srcATop),
                  child: child,
                ),
                child: Image.asset(sprite!, fit: BoxFit.contain, gaplessPlayback: true),
              ),
      ),
    );
  }
}
