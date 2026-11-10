import 'dart:async';
import 'dart:math';

import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../skin/chapter_card_overlay.dart';

/// A line with its text tags (`{b}`, `{color=...}`, `{shake}`...) applied, fully shown.
/// Pauses are ignored. Inherits the surrounding [DefaultTextStyle], merged with [style].
class TaggedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  const TaggedText(this.text, {super.key, this.style, this.textAlign});

  @override
  Widget build(BuildContext context) {
    final glyphs = _Glyphs.of(TextMarkup.parse(text), msPerChar: 0);
    return _GlyphLine(glyphs: glyphs.list, visible: glyphs.list.length, style: style, textAlign: textAlign);
  }
}

/// Types a tagged line out: `{speed}` changes the pace, `{w=ms}` pauses, `{w}` stops until [complete].
/// The hidden rest of the line is laid out already, so words don't jump between lines while typing.
///
/// [builder] wraps the text, with `done` true once the line is typed out or stopped at a `{w}`.
/// While a chapter card is up ([ChapterCardOverlay.holdsDialogue]) the line waits for it.
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  /// Shows the whole line at once, ignoring pauses (skip mode, restored lines).
  final bool instant;

  /// Base typing speed. 0 shows each part between pauses at once.
  final int msPerChar;

  /// Continues by itself after this long at a `{w}` (auto mode). Null waits for [complete].
  final Duration? autoResume;

  /// Called once the line is fully shown, typed out or completed.
  final VoidCallback? onTyped;

  final Widget Function(BuildContext context, Widget text, bool done) builder;

  const TypewriterText(
    this.text, {
    super.key,
    required this.builder,
    this.style,
    this.instant = false,
    this.msPerChar = 40,
    this.autoResume,
    this.onTyped,
  });

  @override
  State<TypewriterText> createState() => TypewriterTextState();
}

class TypewriterTextState extends State<TypewriterText> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status.isCompleted) _partDone();
    });

  late _Glyphs _glyphs;
  int _part = 0;

  /// Stopped at a `{w}`.
  bool _waiting = false;
  Timer? _resume;

  /// A chapter card is up: the line waits for it.
  bool _held = false;
  bool _pending = true;

  @override
  void initState() {
    super.initState();
    _parse();
  }

  void _parse() => _glyphs = _Glyphs.of(TextMarkup.parse(widget.text), msPerChar: widget.msPerChar);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _held = ChapterCardOverlay.holdsDialogue(context);
    if (!_held && _pending) _start();
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text) {
      if (_waiting && widget.autoResume != null && _resume == null) _scheduleResume();
      // The same line again: no new animation, so report it as shown right away.
      if (_finished) _typed();
      return;
    }
    _parse();
    _pending = true;
    if (!_held) _start();
  }

  bool get _finished => _part == _glyphs.parts.length - 1 && _clock.isCompleted && !_waiting;

  void _start() {
    _pending = false;
    _cancelResume();
    _waiting = false;
    if (widget.instant) {
      _part = _glyphs.parts.length - 1;
      final wasCompleted = _clock.isCompleted;
      _clock.value = 1;
      if (wasCompleted) _typed();
      _rebuild();
      return;
    }
    _play(0);
  }

  void _play(int part) {
    _part = part;
    final ms = _glyphs.parts[part].durationMs;
    if (ms == 0) {
      // A zero-length animation doesn't report its status reliably: finish the part directly.
      final wasCompleted = _clock.isCompleted;
      _clock.value = 1;
      if (wasCompleted) _partDone();
    } else {
      _clock.duration = Duration(milliseconds: ms);
      _clock.forward(from: 0);
    }
    _rebuild();
  }

  /// [build] reads [_part] and [_waiting]. During a build phase this widget is being built anyway.
  void _rebuild() {
    if (mounted && SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) setState(() {});
  }

  void _partDone() {
    if (_glyphs.parts[_part].waitsForTap) {
      _waiting = true;
      _rebuild();
      if (widget.autoResume != null) _scheduleResume();
    } else {
      _typed();
    }
  }

  void _scheduleResume() {
    _resume = Timer(widget.autoResume!, () {
      _resume = null;
      if (mounted && _waiting) _continue();
    });
  }

  void _cancelResume() {
    _resume?.cancel();
    _resume = null;
  }

  void _continue() {
    _cancelResume();
    _waiting = false;
    _play(_part + 1);
  }

  /// Runs after the frame: the line can be shown during a build, and the listener rebuilds its parent.
  void _typed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onTyped?.call();
    });
  }

  bool get isTyping => _clock.isAnimating;

  /// Finishes the part being typed, or continues after a `{w}`. False if the line was already shown.
  bool complete() {
    if (_held || _pending) return false;
    if (isTyping) {
      _clock.value = 1;
      return true;
    }
    if (_waiting) {
      _continue();
      return true;
    }
    return false;
  }

  /// The text shown so far, without the hidden rest.
  String get visibleText => _glyphs.list.take(_visible).map((glyph) => glyph.text).join();

  int get _visible {
    final part = _glyphs.parts[_part];
    final elapsed = _clock.value * part.durationMs;
    var visible = part.start;
    while (visible < part.end && _glyphs.list[visible].revealMs <= elapsed) {
      visible++;
    }
    return visible;
  }

  @override
  void dispose() {
    _cancelResume();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final visible = _visible;
        final done = !_clock.isAnimating && (_waiting || visible == _glyphs.list.length);
        return widget.builder(
          context,
          _GlyphLine(glyphs: _glyphs.list, visible: visible, style: widget.style),
          done,
        );
      },
    );
  }
}

/// One grapheme of a line and when it appears, counted from the start of its part.
class _Glyph {
  final String text;
  final MarkupStyle style;
  final int revealMs;

  const _Glyph(this.text, this.style, this.revealMs);
}

/// The glyphs from [start] to [end], typed over [durationMs]. Parts are split at `{w}`.
class _Part {
  final int start;
  final int end;
  final int durationMs;
  final bool waitsForTap;

  const _Part(this.start, this.end, this.durationMs, {required this.waitsForTap});
}

class _Glyphs {
  final List<_Glyph> list;
  final List<_Part> parts;

  const _Glyphs(this.list, this.parts);

  factory _Glyphs.of(TextMarkup markup, {required int msPerChar}) {
    final glyphs = <_Glyph>[];
    final parts = <_Part>[];
    var start = 0;
    var time = 0.0;
    for (final token in markup.tokens) {
      switch (token) {
        case MarkupText(:final text, :final style):
          for (final grapheme in text.characters) {
            time += msPerChar / style.speed;
            glyphs.add(_Glyph(grapheme, style, time.round()));
          }
        case MarkupPause(:final ms?):
          time += ms;
        case MarkupPause():
          parts.add(_Part(start, glyphs.length, time.round(), waitsForTap: true));
          start = glyphs.length;
          time = 0;
      }
    }
    parts.add(_Part(start, glyphs.length, time.round(), waitsForTap: false));
    return _Glyphs(glyphs, parts);
  }
}

/// Draws [glyphs], the ones from [visible] on transparent. Animates `{shake}` / `{wave}` glyphs.
class _GlyphLine extends StatefulWidget {
  final List<_Glyph> glyphs;
  final int visible;
  final TextStyle? style;
  final TextAlign? textAlign;

  const _GlyphLine({required this.glyphs, required this.visible, this.style, this.textAlign});

  @override
  State<_GlyphLine> createState() => _GlyphLineState();
}

class _GlyphLineState extends State<_GlyphLine> with SingleTickerProviderStateMixin {
  late final AnimationController _motion =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  bool get _moves => widget.glyphs.any((glyph) => glyph.style.effect != MarkupEffect.none);

  @override
  void initState() {
    super.initState();
    _updateMotion();
  }

  @override
  void didUpdateWidget(_GlyphLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateMotion();
  }

  void _updateMotion() {
    final reduce = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (_moves && !reduce) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  static Color? parseColor(String? hex) {
    if (hex == null) return null;
    final digits = hex.substring(1);
    final value = int.parse(digits, radix: 16);
    return Color(digits.length > 6 ? value : 0xFF000000 | value);
  }

  TextStyle _styleOf(MarkupStyle style, double baseSize, bool hidden) {
    final decorations = [
      if (style.underline) TextDecoration.underline,
      if (style.strike) TextDecoration.lineThrough,
    ];
    return TextStyle(
      fontWeight: style.bold ? FontWeight.bold : null,
      fontStyle: style.italic ? FontStyle.italic : null,
      decoration: decorations.isEmpty ? null : TextDecoration.combine(decorations),
      fontSize: style.size == 1 ? null : baseSize * style.size,
      color: hidden ? Colors.transparent : parseColor(style.color),
      decorationColor: hidden ? Colors.transparent : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(widget.style);
    final baseSize = base.fontSize ?? 14;
    final moving = _moves;

    InlineSpan spans(double phase) {
      final children = <InlineSpan>[];
      final buffer = StringBuffer();
      MarkupStyle? runStyle;
      var runHidden = false;

      void flush() {
        if (buffer.isEmpty) return;
        children.add(TextSpan(text: buffer.toString(), style: _styleOf(runStyle!, baseSize, runHidden)));
        buffer.clear();
      }

      for (final (index, glyph) in widget.glyphs.indexed) {
        final hidden = index >= widget.visible;
        final style = glyph.style;
        if (style.effect == MarkupEffect.none) {
          if (style != runStyle || hidden != runHidden) flush();
          runStyle = style;
          runHidden = hidden;
          buffer.write(glyph.text);
          continue;
        }
        flush();
        runStyle = null;
        final size = baseSize * style.size;
        final angle = phase * 2 * pi;
        final offset = switch (style.effect) {
          MarkupEffect.shake => Offset(sin(angle * 9 + index * 1.7), cos(angle * 11 + index * 2.3)) * size * 0.06,
          MarkupEffect.wave => Offset(0, sin(angle * 2 + index * 0.6) * size * 0.18),
          MarkupEffect.none => Offset.zero,
        };
        children.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Transform.translate(
            offset: hidden ? Offset.zero : offset,
            child: Text(glyph.text, style: base.merge(_styleOf(style, baseSize, hidden))),
          ),
        ));
      }
      flush();
      return TextSpan(children: children);
    }

    if (!moving) return Text.rich(spans(0), style: widget.style, textAlign: widget.textAlign);
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, _) => Text.rich(spans(_motion.value), style: widget.style, textAlign: widget.textAlign),
    );
  }
}
