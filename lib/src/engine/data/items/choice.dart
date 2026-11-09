import 'package:fsse/src/engine/data/items/profile_info.dart';
import 'package:fsse/src/engine/utils/var_replacer.dart';

import 'base.dart';

class ChoiceItemType extends ItemType {
  static const type = "CHOICE";

  final String text;
  final String? variable;
  final ProfileInfo? profile;
  final List<Choice> choices;

  const ChoiceItemType(this.text, this.variable, this.profile, this.choices);

  factory ChoiceItemType.fromJson(Map<String, dynamic> json) {
    final jsonChoices = json["choices"] as List<dynamic>;
    final profileIdentifier = json["profile"] as String?;

    return ChoiceItemType(
      json["text"] as String,
      json["variable"] as String?,
      profileIdentifier != null ? ProfileInfo.fromIdentifier(profileIdentifier) : null,
      jsonChoices.map((e) => Choice.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  @override
  String? getText() => text;

  @override
  String getType() => type;

  @override
  ProfileInfo? getProfileInfo() => profile;

  @override
  ItemType cloneWithData(Map<String, String> data) {
    final newChoices =
        choices.map((e) => Choice(e.text.replaceWithVars(data), e.value?.replaceWithVars(data), e.target)).toList();
    return ChoiceItemType(text.replaceWithVars(data), variable, profile, newChoices);
  }
}

class Choice {
  final String text;
  final String? value;
  final String? target;

  const Choice(this.text, this.value, this.target);

  factory Choice.fromJson(Map<String, dynamic> json) {
    return Choice(
      json["text"] as String,
      json["value"] as String?,
      json["target"] as String?,
    );
  }
}

