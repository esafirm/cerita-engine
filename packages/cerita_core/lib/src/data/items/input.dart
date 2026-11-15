import 'package:cerita_core/src/data/items/profile_info.dart';
import 'package:cerita_core/src/l10n/localized_text.dart';

import 'base.dart';

/// Free-text player input stored in `dataMap[variable]`.
class InputItemType extends ItemType {
  static const type = "INPUT";

  final String text;
  final String variable;
  final String? defaultValue;
  final ProfileInfo? profile;

  InputItemType.fromJson(super.json, {Localizer localizer = const Localizer()})
      : text = localizer.required(json, "text"),
        variable = json["variable"] as String,
        defaultValue = switch (json["default_value"]) {
          Map value => localizer.json(value),
          final value => value?.toString(),
        },
        profile = ProfileInfo.parse(json["profile"]);

  @override
  String getType() => type;

  @override
  String? getText() => text;

  @override
  ProfileInfo? getProfileInfo() => profile;
}
