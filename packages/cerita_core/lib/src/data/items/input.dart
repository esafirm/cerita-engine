import 'package:cerita_core/src/data/items/profile_info.dart';
import 'package:cerita_core/src/l10n/localized_text.dart';

import 'base.dart';

/// The keyboard an INPUT opens, and the characters it takes.
enum InputKeyboard {
  /// Any text. The default.
  text,

  /// The number pad, and only the digits 0 to 9. The answer stays text, so leading zeros are kept.
  digits;

  static InputKeyboard fromName(String? name) => values.where((value) => value.name == name).firstOrNull ?? text;
}

/// Free-text player input stored in `dataMap[variable]`.
class InputItemType extends ItemType {
  static const type = "INPUT";

  final String text;
  final String variable;
  final String? defaultValue;
  final ProfileInfo? profile;
  final InputKeyboard keyboard;

  /// The fewest characters the answer needs before it can be sent. Null: any length, empty included.
  final int? minLength;

  /// The most characters the field takes. Null: no limit.
  final int? maxLength;

  InputItemType.fromJson(super.json, {Localizer localizer = const Localizer()})
      : text = localizer.required(json, "text"),
        variable = json["variable"] as String,
        defaultValue = switch (json["default_value"]) {
          Map value => localizer.json(value),
          final value => value?.toString(),
        },
        profile = ProfileInfo.parse(json["profile"]),
        keyboard = InputKeyboard.fromName(json["keyboard"] as String?),
        minLength = (json["min_length"] as num?)?.toInt(),
        maxLength = (json["max_length"] as num?)?.toInt();

  static final _digits = RegExp(r"^[0-9]*$");

  /// Whether [value] (already trimmed) can be sent: long enough, not too long, and only digits for
  /// [InputKeyboard.digits].
  bool accepts(String value) {
    if (value.length < (minLength ?? 0)) return false;
    if (maxLength != null && value.length > maxLength!) return false;
    return keyboard != InputKeyboard.digits || _digits.hasMatch(value);
  }

  @override
  String getType() => type;

  @override
  String? getText() => text;

  @override
  ProfileInfo? getProfileInfo() => profile;
}
