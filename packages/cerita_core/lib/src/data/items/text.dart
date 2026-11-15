import 'package:cerita_core/src/data/items/profile_info.dart';
import 'package:cerita_core/src/l10n/localized_text.dart';

import 'base.dart';
import 'sprite_position.dart';

/// A spoken line in VN mode or a message bubble in chat mode.
class TextItemType extends ItemType {
  static const type = "TEXT";

  final String text;
  final ProfileInfo? profile;
  final SpritePosition? position;
  final int? typingDelayMs;
  final String? sfx;

  /// Voice-over clip. Players try its per-locale variant first, see [localizedAssetName].
  final String? voice;

  TextItemType.fromJson(super.json, {Localizer localizer = const Localizer()})
      : text = localizer.required(json, "text"),
        profile = ProfileInfo.parse(json["profile"]),
        position = SpritePosition.fromName(json["position"] as String?),
        typingDelayMs = (json["typing_delay_ms"] as num?)?.toInt(),
        sfx = json["sfx"] as String?,
        voice = json["voice"] as String?;

  @override
  String getType() => type;

  @override
  String? getText() => text;

  @override
  ProfileInfo? getProfileInfo() => profile;
}
