import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Falling particles over the stage: `rain`, `snow` or `sakura`. Other names draw nothing.
class WeatherLayer extends StatefulWidget {
  final String weather;

  /// Draws the particles where they are without falling: in a save thumbnail, or with reduced motion.
  final bool still;

  const WeatherLayer({super.key, required this.weather, this.still = false});

  @override
  State<WeatherLayer> createState() => _WeatherLayerState();
}

class _WeatherLayerState extends State<WeatherLayer> with SingleTickerProviderStateMixin {
  static const _supported = {"rain", "snow", "sakura"};

  final _random = Random();
  final _elapsed = ValueNotifier(Duration.zero);
  Duration _accumulated = Duration.zero;
  late final Ticker _ticker;
  late List<_Particle> _particles;

  bool get _active => !widget.still && _supported.contains(widget.weather);

  @override
  void initState() {
    super.initState();
    _particles = _spawn();
    _ticker = createTicker((elapsed) => _elapsed.value = _accumulated + elapsed);
    if (_active) _ticker.start();
  }

  List<_Particle> _spawn() {
    final count = switch (widget.weather) {
      "rain" => 120,
      "snow" => 80,
      "sakura" => 36,
      _ => 0,
    };
    return List.generate(count, (_) => _Particle.random(_random));
  }

  @override
  void didUpdateWidget(WeatherLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weather != widget.weather) _particles = _spawn();
    if (!_active && _ticker.isActive) {
      _accumulated = _elapsed.value;
      _ticker.stop();
    } else if (_active && !_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_particles.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _WeatherPainter(widget.weather, _particles, _elapsed),
        ),
      ),
    );
  }
}

/// Position and motion as fractions of the screen, so particles fit any size.
class _Particle {
  final double x;
  final double y;
  final double speed;
  final double size;
  final double phase;

  const _Particle(this.x, this.y, this.speed, this.size, this.phase);

  factory _Particle.random(Random random) => _Particle(
        random.nextDouble(),
        random.nextDouble(),
        0.6 + random.nextDouble() * 0.8,
        0.5 + random.nextDouble(),
        random.nextDouble() * pi * 2,
      );
}

class _WeatherPainter extends CustomPainter {
  static final _rainPaint = Paint()
    ..color = Colors.white.withAlpha(110)
    ..strokeWidth = 1.2;
  static final _snowPaint = Paint()..color = Colors.white.withAlpha(200);
  static final _sakuraPaint = Paint()..color = const Color(0xFFFFB7C9).withAlpha(210);

  final String weather;
  final List<_Particle> particles;
  final ValueNotifier<Duration> elapsed;

  _WeatherPainter(this.weather, this.particles, this.elapsed) : super(repaint: elapsed);

  @override
  void paint(Canvas canvas, Size size) {
    final seconds = elapsed.value.inMicroseconds / Duration.microsecondsPerSecond;
    switch (weather) {
      case "rain":
        for (final p in particles) {
          final y = (p.y + seconds * 1.6 * p.speed) % 1.0;
          final x = (p.x + y * 0.08) % 1.0;
          final start = Offset(x * size.width, y * size.height);
          canvas.drawLine(start, start + Offset(3, 18 * p.size), _rainPaint);
        }
      case "snow":
        for (final p in particles) {
          final y = (p.y + seconds * 0.08 * p.speed) % 1.0;
          final x = (p.x + sin(seconds * p.speed + p.phase) * 0.02) % 1.0;
          canvas.drawCircle(Offset(x * size.width, y * size.height), 2.2 * p.size, _snowPaint);
        }
      case "sakura":
        for (final p in particles) {
          final y = (p.y + seconds * 0.07 * p.speed) % 1.0;
          final x = (p.x + seconds * 0.03 + sin(seconds * p.speed + p.phase) * 0.03) % 1.0;
          canvas
            ..save()
            ..translate(x * size.width, y * size.height)
            ..rotate(seconds * p.speed + p.phase)
            ..drawOval(Rect.fromCenter(center: Offset.zero, width: 10 * p.size, height: 6 * p.size), _sakuraPaint)
            ..restore();
        }
    }
  }

  @override
  bool shouldRepaint(_WeatherPainter oldDelegate) => oldDelegate.weather != weather || oldDelegate.particles != particles;
}
