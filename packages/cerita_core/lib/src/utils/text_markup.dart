/// Text tags of a line (`{b}`, `{color=#E05050}`, `{w=600}`...), see the data schema §6.
/// [TextMarkup.parse] turns a line into styled runs and pauses. UIs render the runs and time the pauses.
class TextMarkup {
  /// Styled text and pauses, in reading order.
  final List<MarkupToken> tokens;

  /// Ends with `{nw}`: the line moves on by itself once it is typed out.
  final bool noWait;

  const TextMarkup(this.tokens, {this.noWait = false});

  static final _tag = RegExp(r"\{(/?)([a-z]+)(?:=([^{}]*))?\}");

  /// Lines without a `{` can't have tags, which is most of them.
  static TextMarkup parse(String text) {
    if (!text.contains("{")) return TextMarkup([MarkupText(text, const MarkupStyle())]);

    final tokens = <MarkupToken>[];
    final open = <(String, String?)>[];
    var style = const MarkupStyle();
    var noWait = false;
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isEmpty) return;
      final text = buffer.toString();
      buffer.clear();
      // Merges with the previous run when an unknown tag split it.
      if (tokens.lastOrNull case MarkupText(text: final previous, style: final previousStyle)
          when previousStyle == style) {
        tokens[tokens.length - 1] = MarkupText(previous + text, style);
      } else {
        tokens.add(MarkupText(text, style));
      }
    }

    var index = 0;
    for (final match in _tag.allMatches(text)) {
      buffer.write(text.substring(index, match.start));
      index = match.end;
      final closing = match.group(1)!.isNotEmpty;
      final name = match.group(2)!;
      final value = match.group(3);

      if (closing) {
        final at = open.lastIndexWhere((tag) => tag.$1 == name);
        if (at < 0 || !_styleTags.contains(name)) {
          buffer.write(match.group(0));
          continue;
        }
        flush();
        open.removeAt(at);
        style = open.fold(const MarkupStyle(), (style, tag) => _apply(style, tag.$1, tag.$2)!);
        continue;
      }

      switch (name) {
        case "w":
          final ms = value == null ? null : int.tryParse(value.trim());
          if (value != null && ms == null) {
            buffer.write(match.group(0));
            continue;
          }
          flush();
          tokens.add(MarkupPause(ms));
        case "nw" when value == null:
          noWait = true;
        default:
          final next = _apply(style, name, value);
          if (next == null) {
            buffer.write(match.group(0));
            continue;
          }
          flush();
          open.add((name, value));
          style = next;
      }
    }
    buffer.write(text.substring(index));
    flush();
    return TextMarkup(tokens, noWait: noWait);
  }

  /// [text] without its tags, as the player reads it.
  static String plain(String text) => parse(text).text;

  static const _styleTags = {"b", "i", "u", "s", "color", "size", "shake", "wave", "speed"};

  /// [style] with the tag applied. Null when the tag is unknown or its value is invalid.
  static MarkupStyle? _apply(MarkupStyle style, String name, String? value) {
    double? number() => value == null ? null : double.tryParse(value.trim());
    return switch (name) {
      "b" when value == null => style.copyWith(bold: true),
      "i" when value == null => style.copyWith(italic: true),
      "u" when value == null => style.copyWith(underline: true),
      "s" when value == null => style.copyWith(strike: true),
      "shake" when value == null => style.copyWith(effect: MarkupEffect.shake),
      "wave" when value == null => style.copyWith(effect: MarkupEffect.wave),
      "color" when value != null && RegExp(r"^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$").hasMatch(value.trim()) =>
        style.copyWith(color: value.trim()),
      "size" when (number() ?? 0) > 0 => style.copyWith(size: number()),
      "speed" when (number() ?? 0) > 0 => style.copyWith(speed: number()),
      _ => null,
    };
  }

  /// The visible text.
  String get text => tokens.whereType<MarkupText>().map((token) => token.text).join();

  /// Whether the line has pauses or speed changes, so it needs more than a plain typewriter.
  bool get hasTiming => tokens.any((token) => token is MarkupPause || (token is MarkupText && token.style.speed != 1));
}

sealed class MarkupToken {
  const MarkupToken();
}

class MarkupText extends MarkupToken {
  final String text;
  final MarkupStyle style;

  const MarkupText(this.text, this.style);

  @override
  bool operator ==(Object other) => other is MarkupText && other.text == text && other.style == style;

  @override
  int get hashCode => Object.hash(text, style);

  @override
  String toString() => "MarkupText('$text', $style)";
}

/// `{w=ms}` pauses typing, `{w}` ([ms] null) waits for a tap.
class MarkupPause extends MarkupToken {
  final int? ms;

  const MarkupPause(this.ms);

  bool get waitsForTap => ms == null;

  @override
  bool operator ==(Object other) => other is MarkupPause && other.ms == ms;

  @override
  int get hashCode => ms.hashCode;

  @override
  String toString() => "MarkupPause($ms)";
}

enum MarkupEffect { none, shake, wave }

class MarkupStyle {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;

  /// `#RRGGBB` or `#AARRGGBB`.
  final String? color;

  /// Relative to the surrounding text.
  final double size;
  final MarkupEffect effect;

  /// Multiplies the typing speed.
  final double speed;

  const MarkupStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.color,
    this.size = 1,
    this.effect = MarkupEffect.none,
    this.speed = 1,
  });

  MarkupStyle copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strike,
    String? color,
    double? size,
    MarkupEffect? effect,
    double? speed,
  }) =>
      MarkupStyle(
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        strike: strike ?? this.strike,
        color: color ?? this.color,
        size: size ?? this.size,
        effect: effect ?? this.effect,
        speed: speed ?? this.speed,
      );

  @override
  bool operator ==(Object other) =>
      other is MarkupStyle &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.strike == strike &&
      other.color == color &&
      other.size == size &&
      other.effect == effect &&
      other.speed == speed;

  @override
  int get hashCode => Object.hash(bold, italic, underline, strike, color, size, effect, speed);

  @override
  String toString() => "MarkupStyle(${[
        if (bold) "b",
        if (italic) "i",
        if (underline) "u",
        if (strike) "s",
        if (color != null) "color=$color",
        if (size != 1) "size=$size",
        if (effect != MarkupEffect.none) effect.name,
        if (speed != 1) "speed=$speed",
      ].join(",")})";
}
