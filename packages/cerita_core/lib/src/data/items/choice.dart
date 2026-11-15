import 'package:cerita_core/src/data/effect.dart';
import 'package:cerita_core/src/data/items/profile_info.dart';
import 'package:cerita_core/src/l10n/localized_text.dart';
import 'package:cerita_core/src/state/story_state.dart';
import 'package:cerita_core/src/utils/condition_evaluator.dart';
import 'package:cerita_core/src/utils/text_markup.dart';

import 'base.dart';

class ChoiceItemType extends ItemType {
  static const type = "CHOICE";

  final String text;
  final String? variable;
  final ProfileInfo? profile;
  final int? timeoutMs;
  final int? defaultChoice;
  final List<Choice> choices;

  ChoiceItemType.fromJson(super.json, {Localizer localizer = const Localizer(), List<Choice>? choices})
      : text = localizer.required(json, "text"),
        variable = json["variable"] as String?,
        profile = ProfileInfo.parse(json["profile"]),
        timeoutMs = (json["timeout_ms"] as num?)?.toInt(),
        defaultChoice = (json["default_choice"] as num?)?.toInt(),
        choices = choices ??
            [
              for (final (index, raw) in (json["choices"] as List<dynamic>).indexed)
                Choice.fromJson(Map<String, dynamic>.from(raw as Map), index: index, localizer: localizer),
            ];

  ChoiceItemType._copy(ChoiceItemType source, this.choices)
      : text = source.text,
        variable = source.variable,
        profile = source.profile,
        timeoutMs = source.timeoutMs,
        defaultChoice = source.defaultChoice,
        super(source.json);

  /// Returns a copy with [choices] replaced, e.g. with runtime flags set or `once` choices removed.
  /// The prompt keeps its language.
  ChoiceItemType withChoices(List<Choice> choices) => ChoiceItemType._copy(this, choices);

  /// Returns a copy where choices failing their `condition` are marked [Choice.locked].
  ChoiceItemType withAvailability(bool Function(String? condition) isAvailable) =>
      withChoices(choices.map((choice) => choice.copyWith(locked: !isAvailable(choice.condition))).toList());

  /// The same item in another language. Hidden choices stay hidden, and runtime flags are kept.
  @override
  ChoiceItemType localized(Localizer localizer) {
    final translated = ChoiceItemType.fromJson(json, localizer: localizer);
    final byIndex = {for (final choice in translated.choices) choice.index: choice};
    return translated.withChoices([
      for (final choice in choices)
        if (byIndex[choice.index] case final other?) other.copyWith(locked: choice.locked, chosen: choice.chosen),
    ]);
  }

  List<Choice> get availableChoices => choices.where((choice) => !choice.locked).toList();

  /// The choice picked when [timeoutMs] runs out: [defaultChoice] if available, else the first available one.
  Choice? get timeoutChoice {
    final fallback = choices.where((choice) => choice.index == defaultChoice && !choice.locked).firstOrNull;
    return fallback ?? availableChoices.firstOrNull;
  }

  @override
  String? getText() => text;

  @override
  String getType() => type;

  @override
  ProfileInfo? getProfileInfo() => profile;
}

class Choice {
  final String text;

  /// Stored in the CHOICE `variable` when picked. A localized option without a `value` stores its
  /// source-language text without tags, so state doesn't depend on the player's language.
  final dynamic value;
  final String? target;
  final String? condition;
  final List<Effect> effects;

  /// Position in the item's `choices` JSON. Stays the same when other choices are hidden.
  final int index;

  /// Hidden for the rest of the playthrough once picked.
  final bool once;

  /// Marks the option as unlocked by past runs (`memory_marker`). The UI shows a marker while it is available.
  final bool memoryMarker;

  /// The option text in every language, kept for the transcript. Null for a choice built in code.
  final LocalizedText? localizedText;

  /// Runtime flag: the choice `condition` evaluated to false.
  final bool locked;

  /// Runtime flag: the choice was picked in this or an earlier playthrough.
  final bool chosen;

  const Choice(
    this.text, {
    this.value,
    this.target,
    this.condition,
    this.effects = const [],
    this.index = 0,
    this.once = false,
    this.memoryMarker = false,
    this.localizedText,
    this.locked = false,
    this.chosen = false,
  });

  factory Choice.fromJson(Map<String, dynamic> json, {int index = 0, Localizer localizer = const Localizer()}) {
    final text = LocalizedText.fromJson(json["text"]) ?? (throw FormatException("Missing 'text'", json));
    return Choice(
      localizer.resolve(text),
      value: json["value"] ??
          (text.isLocalized ? TextMarkup.plain(text.resolve(null, source: localizer.sourceLocale)) : null),
      target: json["target"] as String?,
      condition: json["condition"] as String?,
      effects: Effect.listFromJson(json["effects"]),
      index: index,
      once: json["once"] as bool? ?? false,
      memoryMarker: json["memory_marker"] as bool? ?? false,
      localizedText: text,
    );
  }

  /// Whether the `condition` reads cross-playthrough memory (`meta.*`). Such a choice is hidden, not shown
  /// locked, while its condition fails.
  bool get readsMemory => condition != null && ConditionEvaluator.variablesOf(condition!).any(StoryState.isMeta);

  Choice copyWith({bool? locked, bool? chosen}) => Choice(
        text,
        value: value,
        target: target,
        condition: condition,
        effects: effects,
        index: index,
        once: once,
        memoryMarker: memoryMarker,
        localizedText: localizedText,
        locked: locked ?? this.locked,
        chosen: chosen ?? this.chosen,
      );
}
