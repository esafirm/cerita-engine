import '../l10n/localized_text.dart';

/// The optional `credits.json`: who made the story and the third-party assets it uses. See data schema §9.
class Credits {
  final List<CreditSection> sections;
  final List<AssetCredit> assets;

  /// `ending_id`s after which the credits roll.
  final Set<String> rollAfter;

  const Credits({this.sections = const [], this.assets = const [], this.rollAfter = const {}});

  factory Credits.fromJson(Map<String, dynamic> json) => Credits(
        sections: [for (final section in _list(json, "sections")) CreditSection.fromJson(section)],
        assets: [for (final asset in _list(json, "assets")) AssetCredit.fromJson(asset)],
        rollAfter: {for (final id in json["roll_after"] as List<dynamic>? ?? const []) id as String},
      );

  /// Whether the credits roll after the ending [endingId].
  bool rollsAfter(String endingId) => rollAfter.contains(endingId);

  static Iterable<Map<String, dynamic>> _list(Map<String, dynamic> json, String key) =>
      (json[key] as List<dynamic>? ?? const []).map((value) => Map<String, dynamic>.from(value as Map));
}

class CreditSection {
  final LocalizedText title;
  final List<PersonCredit> people;

  const CreditSection({required this.title, this.people = const []});

  factory CreditSection.fromJson(Map<String, dynamic> json) => CreditSection(
        title: _required(json, "title"),
        people: [for (final person in Credits._list(json, "people")) PersonCredit.fromJson(person)],
      );
}

class PersonCredit {
  final LocalizedText name;
  final LocalizedText? role;

  const PersonCredit({required this.name, this.role});

  factory PersonCredit.fromJson(Map<String, dynamic> json) =>
      PersonCredit(name: _required(json, "name"), role: LocalizedText.fromJson(json["role"]));
}

/// A third-party asset and its license terms.
class AssetCredit {
  final LocalizedText title;
  final String author;

  /// Where it came from, usually a URL. Shown as text.
  final String source;

  /// The license name, e.g. `CC0 1.0`.
  final String license;

  /// What the story uses it for.
  final LocalizedText? note;

  const AssetCredit({
    required this.title,
    required this.author,
    required this.source,
    required this.license,
    this.note,
  });

  factory AssetCredit.fromJson(Map<String, dynamic> json) {
    String field(String key) => json[key] as String? ?? (throw FormatException("An asset needs '$key'", json));
    return AssetCredit(
      title: _required(json, "title"),
      author: field("author"),
      source: field("source"),
      license: field("license"),
      note: LocalizedText.fromJson(json["note"]),
    );
  }
}

LocalizedText _required(Map<String, dynamic> json, String key) =>
    LocalizedText.fromJson(json[key]) ?? (throw FormatException("Missing '$key'", json));
