import 'package:fsse/src/engine/data/items/profile_info.dart';
import 'package:fsse/src/engine/utils/var_replacer.dart';

import 'base.dart';

class TextItemType extends ItemType {
  static const type = "TEXT";

  final String text;
  final ProfileInfo? profile;

  const TextItemType(this.text, this.profile);

  factory TextItemType.fromJson(Map<String, dynamic> json) {
    final profileIdentifier = json["profile"] as String?;
    return TextItemType(
      json["text"] as String,
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
    return TextItemType(text.replaceWithVars(data), profile);
  }
}

