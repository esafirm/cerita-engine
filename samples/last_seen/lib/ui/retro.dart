import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:cerita_ui/cerita_ui.dart';
import 'package:flutter/material.dart';

/// The Last Seen look: a 1990s PC visual novel. Framed navy windows, a dot font, hard shadows,
/// stepped fades and square-wave blips. No gradients, no glow, no blur.
abstract final class Retro {
  static const font = "DotGothic16";

  static const night = Color(0xFF0A0E1E);
  static const ink = Color(0xF0111737);
  static const frame = Color(0xFFF4F1E8);
  static const line = Color(0xFF6F7BC0);
  static const accent = Color(0xFFFF8FB8);
  static const dim = Color(0xFF8C94B8);
  static const narration = Color(0xFFB9C6F2);

  static const shadow = BoxShadow(color: Color(0xAA000000), offset: Offset(4, 4));

  static const text = TextStyle(fontFamily: font, color: frame, fontSize: 16, height: 1.6, letterSpacing: 0.4);

  /// The app theme: the shared dark theme with the dot font and square framed surfaces.
  static ThemeData theme() {
    final base = CeritaTheme.dark();
    const square = RoundedRectangleBorder(side: BorderSide(color: frame, width: 2));
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: font),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: font),
      scaffoldBackgroundColor: night,
      colorScheme: base.colorScheme.copyWith(primary: accent, onPrimary: night, surface: const Color(0xFF111737)),
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(fontFamily: font, letterSpacing: 2),
      ),
      cardTheme: base.cardTheme.copyWith(color: ink, shape: square),
      dialogTheme: base.dialogTheme.copyWith(backgroundColor: const Color(0xFF111737), shape: square),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: const Color(0xFF111737),
        contentTextStyle: text,
        shape: square,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(),
          textStyle: const TextStyle(fontFamily: font, letterSpacing: 1.6),
        ),
      ),
    );
  }
}

/// The PC-98 style window: navy fill, a white outer frame, an inner rule and a hard drop shadow.
class RetroWindow extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color fill;

  const RetroWindow({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.fill = Retro.ink});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: Retro.frame, width: 2),
        boxShadow: const [Retro.shadow],
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        padding: padding,
        decoration: BoxDecoration(border: Border.all(color: Retro.line)),
        child: child,
      ),
    );
  }
}

/// Moves in [steps] hard jumps instead of a smooth ramp, for fades that look like an old palette fade.
class SteppedCurve extends Curve {
  final int steps;

  const SteppedCurve(this.steps);

  @override
  double transformInternal(double t) => (t * steps).floor() / steps;
}

/// Switches [child] on and off, like a "press start" prompt or a waiting cursor.
class Blink extends StatefulWidget {
  final Widget child;
  final Duration period;

  const Blink({super.key, required this.child, this.period = const Duration(milliseconds: 1000)});

  @override
  State<Blink> createState() => _BlinkState();
}

class _BlinkState extends State<Blink> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (context, child) => Opacity(opacity: _clock.value < 0.6 ? 1 : 0, child: child),
    child: widget.child,
  );
}

/// Square-wave menu blips, at the player's sound volume.
class UiSounds {
  /// Set once in `main`. Skins are const, so they reach the sounds through here.
  static UiSounds? instance;

  final StorySetup setup;
  final AudioHelper _audio = AudioHelper();

  UiSounds(this.setup);

  void _play(String name) {
    final volume = setup.settings.value.soundVolume;
    _audio.setVolumes(music: 0, sound: volume, voice: 0);
    if (volume > 0) _audio.playSfx(setup.config.music(name));
  }

  void cursor() => _play("sfx_ui_cursor.mp3");
  void confirm() => _play("sfx_ui_confirm.mp3");
  void cancel() => _play("sfx_ui_cancel.mp3");
  void start() => _play("sfx_ui_start.mp3");
}

/// The menu cursor: a solid right-pointing triangle. Drawn, not typed, so Android never swaps in the ▶ emoji.
class RetroCursor extends StatelessWidget {
  final Color color;
  final double size;

  const RetroCursor({super.key, this.color = Retro.accent, this.size = 12});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(size * 0.8, size), painter: _CursorPainter(color));
}

class _CursorPainter extends CustomPainter {
  final Color color;

  const _CursorPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CursorPainter oldDelegate) => color != oldDelegate.color;
}
