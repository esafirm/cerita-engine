import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'cerita_theme.dart';

class TitleMenuEntry {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const TitleMenuEntry({required this.label, required this.icon, required this.onTap});
}

/// Animated VN title screen: slowly drifting key art, floating light motes, the title
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

  late final AnimationController _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 24))
    ..repeat(reverse: true);

  late final AnimationController _motes = AnimationController(vsync: this, duration: const Duration(seconds: 40))
    ..repeat();

  Animation<double> _interval(double begin, double end) => CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

  @override
  void dispose() {
    _intro.dispose();
    _ambient.dispose();
    _motes.dispose();
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
            child: FadeTransition(opacity: _interval(0, 0.5), child: widget.art),
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
          IgnorePointer(child: CustomPaint(painter: _MotesPainter(_motes))),
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
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFFFD6EA), CeritaColors.lavender],
          ).createShader(bounds),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              height: 1.1,
              shadows: [Shadow(color: Color(0x99FF7EB6), blurRadius: 24)],
            ),
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
    final radius = BorderRadius.circular(18);
    return Container(
      padding: const EdgeInsets.all(1.4),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: highlighted ? CeritaColors.accent : null,
        color: highlighted ? null : Colors.white24,
        boxShadow: highlighted ? [BoxShadow(color: CeritaColors.blossom.withAlpha(90), blurRadius: 22)] : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: highlighted ? CeritaColors.night.withAlpha(120) : CeritaColors.night.withAlpha(170),
            child: InkWell(
              onTap: entry.onTap,
              splashColor: CeritaColors.blossom.withAlpha(60),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(entry.icon, color: highlighted ? CeritaColors.blossom : CeritaColors.moon, size: 20),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        entry.label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CeritaColors.moon,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
            InkWell(
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
                        style: TextStyle(color: CeritaColors.moon.withAlpha(190), fontSize: 11, letterSpacing: 0.6),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Soft glowing specks drifting upwards, like dust in moonlight.
class _MotesPainter extends CustomPainter {
  static const _count = 26;

  final Animation<double> animation;

  /// Fixed seeds so the motes keep their identity between frames. Each mote rises a whole
  /// number of times per [animation] loop, so the loop restarts without a jump.
  final List<(double x, int rises, double size, double phase)> _motes;

  _MotesPainter(this.animation)
      : _motes = List.generate(_count, (i) {
          final random = Random(i * 7919);
          return (random.nextDouble(), 2 + random.nextInt(3), 1 + random.nextDouble() * 2.5, random.nextDouble());
        }),
        super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    for (final (x, rises, radius, phase) in _motes) {
      final progress = (phase + animation.value * rises) % 1;
      final dx = (x + 0.03 * sin((progress + phase) * pi * 4)) * size.width;
      final dy = size.height * (1.05 - progress * 1.1);
      final fade = sin(progress * pi);
      paint.color = Color.lerp(CeritaColors.blossom, Colors.white, phase)!.withAlpha((fade * 150).round());
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_MotesPainter oldDelegate) => false;
}
