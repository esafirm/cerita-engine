import 'dart:convert';

import '../l10n/localized_text.dart';

/// A piece of evidence declared in `clues.json`. The player finds it when the playthrough variable
/// [variable] (`clue_<id>`) becomes `true`. See `specs/data-schema.md` section 8.
class Clue {
  static const variablePrefix = "clue_";
  static final idPattern = RegExp(r"^[a-zA-Z0-9_]+$");

  final String id;

  /// Position in `clues.json`.
  final int index;

  /// Text in every language. Resolve it with the engine's `Localizer` for anything the player sees.
  final LocalizedText title;
  final LocalizedText? description;

  /// The day or chapter the board groups the clue under.
  final LocalizedText? chapter;

  /// Image file in `media/`.
  final String? image;

  /// A key clue, marked on the board.
  final bool isKey;

  const Clue({
    required this.id,
    required this.title,
    this.index = 0,
    this.description,
    this.chapter,
    this.image,
    this.isKey = false,
  });

  factory Clue.fromJson(Map<String, dynamic> json, {int index = 0}) {
    final id = json["id"];
    if (id is! String) throw FormatException("A clue needs an 'id'", json);
    return Clue(
      id: id,
      index: index,
      title: LocalizedText.fromJson(json["title"]) ?? (throw FormatException("Clue '$id' needs a 'title'", json)),
      description: LocalizedText.fromJson(json["description"]),
      chapter: LocalizedText.fromJson(json["chapter"]),
      image: json["image"] as String?,
      isKey: json["key"] as bool? ?? false,
    );
  }

  /// The playthrough variable that is `true` once the clue is found.
  String get variable => "$variablePrefix$id";

  /// The clue a `clue_<id>` [variable] name stands for, or null for other names.
  static String? idOf(String variable) =>
      variable.startsWith(variablePrefix) && variable.length > variablePrefix.length
          ? variable.substring(variablePrefix.length)
          : null;
}

/// Clues declared under one chapter, in file order.
class ClueGroup {
  /// The chapter heading. Null for clues without a `chapter`.
  final LocalizedText? chapter;
  final List<Clue> clues;

  const ClueGroup(this.chapter, this.clues);
}

/// Every clue a story declares, from the optional `clues.json`. Empty when the story has none.
class ClueCatalog {
  static const empty = ClueCatalog([]);

  final List<Clue> clues;

  /// Show "3 of 5 found" per chapter on the board.
  final bool showCounts;

  const ClueCatalog(this.clues, {this.showCounts = false});

  factory ClueCatalog.fromJson(Map<String, dynamic> json) => ClueCatalog(
        [
          for (final (index, raw) in (json["clues"] as List<dynamic>? ?? const []).indexed)
            Clue.fromJson(Map<String, dynamic>.from(raw as Map), index: index),
        ],
        showCounts: json["show_counts"] as bool? ?? false,
      );

  bool get isEmpty => clues.isEmpty;

  bool get isNotEmpty => clues.isNotEmpty;

  Clue? byId(String id) => clues.where((clue) => clue.id == id).firstOrNull;

  /// The clues grouped by chapter in board order: newest chapter first (the reverse of the order in which each
  /// chapter's first clue is declared), then the clues without a chapter.
  List<ClueGroup> get groups {
    final byChapter = <String, List<Clue>>{};
    final headings = <String, LocalizedText?>{};
    for (final clue in clues) {
      // Grouped by every language of the heading, so the groups are the same whichever language is shown.
      final key = clue.chapter == null ? "" : jsonEncode(clue.chapter!.toJson());
      byChapter.putIfAbsent(key, () => []).add(clue);
      headings[key] = clue.chapter;
    }
    final groups = [
      for (final MapEntry(:key, :value) in byChapter.entries)
        if (key.isNotEmpty) ClueGroup(headings[key], value),
    ];
    final loose = byChapter[""];
    return [...groups.reversed, if (loose != null) ClueGroup(null, loose)];
  }
}
