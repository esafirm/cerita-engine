import 'package:fsse/src/engine/data/items/profile_info.dart';
import 'package:fsse/src/engine/utils/var_replacer.dart';

import 'base.dart';

class InputItemType extends ItemType {
  static const type = "INPUT";

  final String text;
  final String variable;
  final ProfileInfo? profile;

  const InputItemType(this.text, this.variable, this.profile);

  factory InputItemType.fromJson(Map<String, dynamic> json) {
    final profileIdentifier = json["profile"] as String?;
    return InputItemType(
      json["text"] as String,
      json["variable"] as String,
      profileIdentifier != null ? ProfileInfo.fromIdentifier(profileIdentifier) : null,
    );
  }

  @override
  String getType() => type;

  @override
  String? getText() => text;

  @override
  ProfileInfo? getProfileInfo() => profile;

  @override
  ItemType cloneWithData(Map<String, String> data) {
    return InputItemType(text.replaceWithVars(data), variable, profile);
  }
}

