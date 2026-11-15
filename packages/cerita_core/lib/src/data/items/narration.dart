import 'package:cerita_core/src/l10n/localized_text.dart';

import 'base.dart';

enum NarrationStyle {
  narration,
  system,
  timestamp;

  static NarrationStyle fromName(String? name) => values.where((e) => e.name == name).firstOrNull ?? narration;
}

/// Unattributed narration (VN) or a system / timestamp divider (chat).
class NarrationItemType extends ItemType {
  static const type = "NARRATION";

  final String text;
  final NarrationStyle style;
  final String? sfx;

  NarrationItemType.fromJson(super.json, {Localizer localizer = const Localizer()})
      : text = localizer.required(json, "text"),
        style = NarrationStyle.fromName(json["style"] as String?),
        sfx = json["sfx"] as String?;

  @override
  String getType() => type;

  @override
  String? getText() => text;
}
