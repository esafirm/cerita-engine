import 'dart:math';

import 'package:flutter/material.dart';

import 'cerita_theme.dart';

class TitleMenuEntry {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const TitleMenuEntry({required this.label, required this.icon, required this.onTap});
}

/// Animated VN title screen: slowly drifting key art, the title
/// easing in, and the menu sliding up entry by entry.
class CeritaTitleScreen extends StatefulWidget {
  final String title;
  final String? subtitle;

  /// Key art, usually a background with the cast on top. Drawn edge to edge.
  final Widget art;

  /// Large buttons, e.g. Continue and New game.
  final List<TitleMenuEntry> primary;

  /// Small icon buttons below, e.g. Load, Gallery, Settings.
  final List<TitleMenuEntry> secondary;

  const CeritaTitleScreen({
    super.key,
    required this.title,
    this.subtitle,
    required this.art,
    required this.primary,
    this.secondary = const [],
  });

  @override
  State<CeritaTitleScreen> createState() => _CeritaTitleScreenState();
}

class _CeritaTitleScreenState extends State<CeritaTitleScreen> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..forward();

  late final AnimationController _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void initState() {
    super.initState();
    if (!WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      _ambient.repeat(reverse: true);
    }
  }

  Animation<double> _interval(double begin, double end) =>
      _intro.drive(CurveTween(curve: Interval(begin.clamp(0, 0.9), end.clamp(0.1, 1), curve: Curves.easeOutCubic)));

  @override
  void dispose() {
    _intro.dispose();
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleIn = _interval(0.15, 0.6);
    final entries = [...widget.primary.map((e) => (e, true)), if (widget.secondary.isNotEmpty) (null, false)];

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ken Burns drift of the key art.
          AnimatedBuilder(
            animation: _ambient,
            builder: (context, child) => Transform.scale(
              scale: 1.06 + 0.04 * Curves.easeInOut.transform(_ambient.value),
              alignment: Alignment(0, -0.2 + 0.4 * _ambient.value),
              child: child,
            ),
            child: RepaintBoundary(child: FadeTransition(opacity: _interval(0, 0.5), child: widget.art)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xB30E0F1F), Color(0x000E0F1F), Color(0x660E0F1F), Color(0xF20E0F1F)],
                stops: [0, 0.3, 0.55, 0.9],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeTransition(
                    opacity: titleIn,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, -0.3), end: Offset.zero).animate(titleIn),
                      child: _Title(title: widget.title, subtitle: widget.subtitle),
                    ),
                  ),
                  const Spacer(),
                  for (final (index, (entry, primary)) in entries.indexed)
                    _SlideUp(
                      animation: _interval(0.45 + index * 0.1, min(1, 0.85 + index * 0.1)),
                      child: primary
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PrimaryButton(entry: entry!, highlighted: index == 0),
                            )
                          : _SecondaryRow(entries: widget.secondary),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _Title({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: CeritaColors.moon,
            fontSize: 42,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            height: 1.1,
            // A hard offset shadow, like a cel outline, keeps it readable over the art.
            shadows: [Shadow(color: CeritaColors.night, offset: Offset(0, 3))],
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CeritaColors.moon.withAlpha(190),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 4,
            ),
          ),
        ],
      ],
    );
  }
}

class _SlideUp extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _SlideUp({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final TitleMenuEntry entry;
  final bool highlighted;

  const _PrimaryButton({required this.entry, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final foreground = highlighted ? CeritaColors.night : CeritaColors.moon;
    return Material(
      color: highlighted ? CeritaColors.blossom : CeritaColors.night.withAlpha(215),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: highlighted ? BorderSide.none : const BorderSide(color: Colors.white24, width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: entry.onTap,
        splashColor: (highlighted ? CeritaColors.night : CeritaColors.blossom).withAlpha(50),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(entry.icon, color: foreground, size: 20),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  entry.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: foreground, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryRow extends StatelessWidget {
  final List<TitleMenuEntry> entries;

  const _SecondaryRow({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final entry in entries)
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: entry.onTap,
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 68,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Icon(entry.icon, color: CeritaColors.moon.withAlpha(220), size: 22),
                        const SizedBox(height: 4),
                        Text(
                          entry.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: CeritaColors.moon.withAlpha(190), fontSize: 11, letterSpacing: 0.6),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
