import 'package:cerita_core/src/data/effect.dart';
import 'package:cerita_core/src/data/items/profile_info.dart';

import 'base.dart';

class ChoiceItemType extends ItemType {
  static const type = "CHOICE";

  final String text;
  final String? variable;
  final ProfileInfo? profile;
  final int? timeoutMs;
  final int? defaultChoice;
  final List<Choice> choices;

  ChoiceItemType.fromJson(super.json, {List<Choice>? choices})
      : text = json["text"] as String,
        variable = json["variable"] as String?,
        profile = ProfileInfo.parse(json["profile"]),
        timeoutMs = (json["timeout_ms"] as num?)?.toInt(),
        defaultChoice = (json["default_choice"] as num?)?.toInt(),
        choices = choices ??
            [
              for (final (index, raw) in (json["choices"] as List<dynamic>).indexed)
                Choice.fromJson(Map<String, dynamic>.from(raw as Map), index: index),
            ];

  /// Returns a copy with [choices] replaced, e.g. with runtime flags set or `once` choices removed.
  ChoiceItemType withChoices(List<Choice> choices) => ChoiceItemType.fromJson(json, choices: choices);

  /// Returns a copy where choices failing their `condition` are marked [Choice.locked].
  ChoiceItemType withAvailability(bool Function(String? condition) isAvailable) =>
      withChoices(choices.map((choice) => choice.copyWith(locked: !isAvailable(choice.condition))).toList());

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
  final dynamic value;
  final String? target;
  final String? condition;
  final List<Effect> effects;

  /// Position in the item's `choices` JSON. Stays the same when other choices are hidden.
  final int index;

  /// Hidden for the rest of the playthrough once picked.
  final bool once;

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
    this.locked = false,
    this.chosen = false,
  });

  factory Choice.fromJson(Map<String, dynamic> json, {int index = 0}) {
    return Choice(
      json["text"] as String,
      value: json["value"],
      target: json["target"] as String?,
      condition: json["condition"] as String?,
      effects: Effect.listFromJson(json["effects"]),
      index: index,
      once: json["once"] as bool? ?? false,
    );
  }

  Choice copyWith({bool? locked, bool? chosen}) => Choice(
        text,
        value: value,
        target: target,
        condition: condition,
        effects: effects,
        index: index,
        once: once,
        locked: locked ?? this.locked,
        chosen: chosen ?? this.chosen,
      );
}
