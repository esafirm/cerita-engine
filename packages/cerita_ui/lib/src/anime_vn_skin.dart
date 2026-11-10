import 'dart:ui';

import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';

import 'cerita_theme.dart';

/// Modern anime visual novel look: frosted dialogue box with a slanted name plate,
/// fade-through-black scene changes, sprites that rise into place and a chapter title card.
class AnimeVnSkin extends StorySkin {
  const AnimeVnSkin();

  static const _textShadow = [Shadow(color: Colors.black54, blurRadius: 6)];

  @override
  Duration get sceneTransitionDuration => const Duration(milliseconds: 1100);

  @override
  Widget sceneTransition(SceneMode mode, Animation<double> animation, Widget child) {
    // Every switch dips to black: the outgoing scene runs the reverse animation, so it is gone by
    // the midpoint and the incoming one only appears in the second half. The two never overlap.
    final fadeThrough = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.5, 1, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.5, 1, curve: Curves.easeInCubic),
    );
    return FadeTransition(
      opacity: fadeThrough,
      child: switch (mode) {
        // The phone rises into view.
        SceneMode.chat => SlideTransition(
            position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(fadeThrough),
            child: child,
          ),
        // The call screen settles in.
        SceneMode.call => ScaleTransition(scale: Tween(begin: 1.12, end: 1.0).animate(fadeThrough), child: child),
        SceneMode.vn => child,
      },
    );
  }

  @override
  Duration get backgroundTransitionDuration => const Duration(milliseconds: 900);

  @override
  Widget backgroundTransition(Animation<double> animation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(scale: Tween(begin: 1.08, end: 1.0).animate(curved), child: child),
    );
  }

  @override
  Duration get spriteTransitionDuration => const Duration(milliseconds: 380);

  @override
  Widget spriteTransition(Animation<double> animation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }

  @override
  Duration get chapterCardDuration => const Duration(milliseconds: 2600);

  @override
  Widget? chapterCard(BuildContext context, Conversation conversation) =>
      _ChapterCard(chapter: conversation.chapter!, title: conversation.title);

  @override
  Widget dialogueFrame(BuildContext context, DialogueFrame frame) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 124),
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withAlpha(46)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [CeritaColors.surface.withAlpha(185), CeritaColors.night.withAlpha(225)],
                ),
              ),
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                  color: CeritaColors.moon,
                  shadows: _textShadow,
                ),
                child: frame.body,
              ),
            ),
          ),
        ),
        Positioned(
          left: 18,
          top: -17,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: const Offset(-0.15, 0), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: frame.speaker == null
                ? const SizedBox.shrink()
                : _NamePlate(key: ValueKey(frame.speaker), name: frame.speaker!),
          ),
        ),
        Positioned(
          right: 18,
          bottom: 8,
          child: AnimatedOpacity(
            opacity: frame.done ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: const _NextIndicator(),
          ),
        ),
      ],
    );
  }

  @override
  Widget choiceButton(BuildContext context, Choice choice, int index, VoidCallback? onTap, {required bool dark}) {
    return _StaggeredEntrance(
      index: index,
      child: _ChoiceButton(choice: choice, onTap: onTap),
    );
  }

  @override
  Widget vnHud(BuildContext context, VnHud hud) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            if (hud.label != null) _HudLabel(hud.label!),
            const Spacer(),
            _Glass(
              radius: 999,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HudButton("LOG", onTap: hud.onBacklog),
                  _HudButton("AUTO", active: hud.autoMode, onTap: hud.onAuto),
                  _HudButton("SKIP", active: hud.skipMode, onTap: hud.onSkip),
                  _HudButton("MENU", onTap: hud.onMenu),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NamePlate extends StatelessWidget {
  final String name;

  const _NamePlate({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    // Slanted tab: skew the plate, counter-skew the label so the text stays upright.
    return Transform(
      transform: Matrix4.skewX(-0.22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        decoration: BoxDecoration(
          gradient: CeritaColors.accent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [BoxShadow(color: CeritaColors.blossom.withAlpha(110), blurRadius: 14)],
        ),
        child: Transform(
          transform: Matrix4.skewX(0.22),
          child: Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              fontSize: 15,
              shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bobbing chevron shown once the line is fully typed.
class _NextIndicator extends StatefulWidget {
  const _NextIndicator();

  @override
  State<_NextIndicator> createState() => _NextIndicatorState();
}

class _NextIndicatorState extends State<_NextIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween(
        begin: Offset.zero,
        end: const Offset(0, 0.25),
      ).animate(CurvedAnimation(parent: _bob, curve: Curves.easeInOut)),
      child: const Icon(Icons.keyboard_arrow_down_rounded, color: CeritaColors.blossom, size: 22),
    );
  }
}

/// Slides and fades in, each [index] a beat after the previous one.
class _StaggeredEntrance extends StatelessWidget {
  static const _step = 90;
  static const _length = 320;

  final int index;
  final Widget child;

  const _StaggeredEntrance({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delay = index * _step;
    final total = delay + _length;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(28 * (1 - value), 0), child: child),
      ),
      child: child,
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final Choice choice;
  final VoidCallback? onTap;

  const _ChoiceButton({required this.choice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locked = choice.locked;
    final foreground = locked ? CeritaColors.moon.withAlpha(110) : CeritaColors.moon;
    return Container(
      // Gradient border: the outer box paints the accent, the inner one the glass.
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: locked ? null : CeritaColors.accent,
        color: locked ? Colors.white12 : null,
      ),
      child: Material(
        color: CeritaColors.night.withAlpha(locked ? 170 : 215),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          splashColor: CeritaColors.blossom.withAlpha(70),
          highlightColor: CeritaColors.lavender.withAlpha(40),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (locked) ...[Icon(Icons.lock_outline, size: 16, color: foreground), const SizedBox(width: 8)],
                Flexible(
                  child: Text(
                    choice.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: foreground, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final double radius;
  final Widget child;

  const _Glass({required this.radius, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CeritaColors.night.withAlpha(120),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withAlpha(36)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _HudLabel extends StatelessWidget {
  final String label;

  const _HudLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 999,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 4,
              height: 14,
              decoration: BoxDecoration(gradient: CeritaColors.accent, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: CeritaColors.moon,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HudButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _HudButton(this.label, {this.active = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: active ? CeritaColors.blossom : CeritaColors.moon.withAlpha(200),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            shadows: active ? [Shadow(color: CeritaColors.blossom.withAlpha(180), blurRadius: 10)] : null,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final String chapter;
  final String? title;

  const _ChapterCard({required this.chapter, this.title});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(radius: 1.1, colors: [Color(0xE6181A30), Color(0xFA0E0F1F)]),
      ),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 160 * value,
                height: 1.5,
                decoration: const BoxDecoration(gradient: CeritaColors.accent),
              ),
              const SizedBox(height: 18),
              Text(
                chapter.toUpperCase(),
                style: TextStyle(
                  color: CeritaColors.moon,
                  fontSize: 30,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 4 + 8 * (1 - value),
                ),
              ),
              if (title != null) ...[
                const SizedBox(height: 10),
                Opacity(
                  opacity: value,
                  child: Text(
                    title!,
                    style: const TextStyle(
                      color: CeritaColors.lavender,
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Container(
                width: 160 * value,
                height: 1.5,
                decoration: const BoxDecoration(gradient: CeritaColors.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
