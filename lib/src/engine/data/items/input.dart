import 'package:fsse/src/engine/data/items/profile_info.dart';

import 'base.dart';

/// Free-text player input stored in `dataMap[variable]`.
class InputItemType extends ItemType {
  static const type = "INPUT";

  final String text;
  final String variable;
  final String? defaultValue;
  final ProfileInfo? profile;

  InputItemType.fromJson(super.json)
      : text = json["text"] as String,
        variable = json["variable"] as String,
        defaultValue = json["default_value"]?.toString(),
        profile = ProfileInfo.parse(json["profile"]);

  @override
  String getType() => type;

  @override
  String? getText() => text;

  @override
  ProfileInfo? getProfileInfo() => profile;
}
