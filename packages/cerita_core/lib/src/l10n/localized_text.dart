/// Text of a localizable field: a plain string, the same in every language, or one string per locale
/// (`{"id": "Hai", "en": "Hi"}`). See `specs/data-schema.md` section 5.
final class LocalizedText {
  final String? _plain;
  final Map<String, String> _locales;

  const LocalizedText(String text)
      : _plain = text,
        _locales = const {};

  LocalizedText.locales(Map<String, String> locales)
      : _plain = null,
        _locales = Map.unmodifiable(locales) {
    if (locales.isEmpty) throw ArgumentError.value(locales, "locales", "needs at least one locale");
  }

  /// Parses a JSON field. Null stays null. Locales with a null value are left out.
  static LocalizedText? fromJson(Object? json) => switch (json) {
        null => null,
        String text => LocalizedText(text),
        Map map when map.values.any((value) => value != null) => LocalizedText.locales({
            for (final MapEntry(:key, :value) in map.entries)
              if (value != null) key.toString(): value.toString(),
          }),
        _ => throw FormatException("Expected a string or an object of locale to string", json),
      };

  /// Whether the text is written per locale, rather than one string for every language.
  bool get isLocalized => _plain == null;

  /// The locales this text is written in. Empty for plain text.
  Iterable<String> get locales => _locales.keys;

  /// The text in [locale], else in [source], else in the first locale listed.
  String resolve(String? locale, {String source = StoryLocales.defaultSource}) =>
      _plain ?? _locales[locale] ?? _locales[source] ?? _locales.values.first;

  /// Applies [transform] to the text of every locale.
  LocalizedText map(String Function(String text) transform) => switch (_plain) {
        final plain? => LocalizedText(transform(plain)),
        null => LocalizedText.locales(_locales.map((locale, text) => MapEntry(locale, transform(text)))),
      };

  /// The JSON form it was read from: a string or a map.
  Object toJson() => _plain ?? _locales;

  @override
  bool operator ==(Object other) =>
      other is LocalizedText &&
      other._plain == _plain &&
      other._locales.length == _locales.length &&
      _locales.entries.every((entry) => other._locales[entry.key] == entry.value);

  @override
  int get hashCode =>
      Object.hash(_plain, Object.hashAllUnordered([for (final entry in _locales.entries) (entry.key, entry.value)]));

  /// The source-language text. Use a [Localizer] for anything the player sees.
  @override
  String toString() => resolve(null);
}

/// The languages a story is written in, declared at the top level of `index.json`.
class StoryLocales {
  static const defaultSource = "id";

  /// The language the story is written in first. Text missing in the active locale falls back to it.
  final String source;

  final List<String> _declared;

  const StoryLocales({this.source = defaultSource, List<String> locales = const []}) : _declared = locales;

  factory StoryLocales.fromJson(Map<String, dynamic> json) => StoryLocales(
        source: json["source_locale"] as String? ?? defaultSource,
        locales: [for (final locale in json["locales"] as List<dynamic>? ?? const []) locale.toString()],
      );

  /// Every language the story offers, in declared order. Just [source] when none are declared.
  List<String> get supported => [..._declared, if (!_declared.contains(source)) source];

  bool supports(String locale) => supported.contains(locale);
}

/// Resolves localized text in the active [locale], falling back to [sourceLocale].
class Localizer {
  /// The player's language. Null shows the source language.
  final String? locale;
  final String sourceLocale;

  const Localizer({this.locale, this.sourceLocale = StoryLocales.defaultSource});

  /// The locale whose text and voice clips are shown: [locale], else [sourceLocale].
  String get activeLocale => locale ?? sourceLocale;

  String resolve(LocalizedText text) => text.resolve(locale, source: sourceLocale);

  String? maybe(LocalizedText? text) => text == null ? null : resolve(text);

  /// Resolves a raw JSON field: a string, a locale map or null.
  String? json(Object? value) => maybe(LocalizedText.fromJson(value));

  /// Resolves a required JSON field of [json].
  String required(Map<String, dynamic> json, String key) =>
      this.json(json[key]) ?? (throw FormatException("Missing '$key'", json));

  @override
  bool operator ==(Object other) => other is Localizer && other.locale == locale && other.sourceLocale == sourceLocale;

  @override
  int get hashCode => Object.hash(locale, sourceLocale);
}

/// The per-locale variant of an asset file name: `vo_nora.mp3` becomes `vo_nora.en.mp3`.
/// Players try it before [name] itself.
String localizedAssetName(String name, String locale) {
  final slash = name.lastIndexOf("/");
  final dot = name.lastIndexOf(".");
  if (dot <= slash + 1) return "$name.$locale";
  return "${name.substring(0, dot)}.$locale${name.substring(dot)}";
}
