import 'package:fsse/src/engine/data/effect.dart';
import 'package:fsse/src/engine/data/items/profile_info.dart';

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
            (json["choices"] as List<dynamic>).map((e) => Choice.fromJson(Map<String, dynamic>.from(e as Map))).toList();

  /// Returns a copy where choices failing their `condition` are marked [Choice.locked].
  ChoiceItemType withAvailability(bool Function(String? condition) isAvailable) {
    return ChoiceItemType.fromJson(
      json,
      choices: choices.map((choice) => choice.copyWith(locked: !isAvailable(choice.condition))).toList(),
    );
  }

  List<Choice> get availableChoices => choices.where((choice) => !choice.locked).toList();

  /// The choice picked when [timeoutMs] runs out: [defaultChoice] if available, else the first available one.
  Choice? get timeoutChoice {
    final index = defaultChoice;
    if (index != null && index >= 0 && index < choices.length && !choices[index].locked) return choices[index];
    return availableChoices.firstOrNull;
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

  /// Runtime flag: the choice `condition` evaluated to false.
  final bool locked;

  const Choice(this.text, {this.value, this.target, this.condition, this.effects = const [], this.locked = false});

  factory Choice.fromJson(Map<String, dynamic> json) {
    return Choice(
      json["text"] as String,
      value: json["value"],
      target: json["target"] as String?,
      condition: json["condition"] as String?,
      effects: Effect.listFromJson(json["effects"]),
    );
  }

  Choice copyWith({required bool locked}) =>
      Choice(text, value: value, target: target, condition: condition, effects: effects, locked: locked);
}
