import 'package:cerita_core/src/data/items/profile_info.dart';
import 'package:cerita_core/src/l10n/localized_text.dart';

import 'base.dart';

enum MediaType {
  image("IMAGE"),
  audio("AUDIO"),
  video("VIDEO"),
  cg("CG");

  final String key;

  const MediaType(this.key);

  static MediaType fromKey(String? key) =>
      values.where((e) => e.key == key).firstOrNull ?? (throw Exception("Unknown media_type '$key'"));
}

/// Photo, voice note, video or full-screen CG. [unlockId] registers it in the Gallery, named by [title].
class MediaItemType extends ItemType {
  static const type = "MEDIA";

  final MediaType mediaType;

  /// File name. For [MediaType.audio], players try its per-locale variant first, see [localizedAssetName].
  final String uri;

  /// Display name in the Gallery and the unlock toast.
  final String? title;
  final String? caption;
  final String? transcript;
  final ProfileInfo? profile;
  final String? unlockId;
  final int? typingDelayMs;
  final String? sfx;

  MediaItemType.fromJson(super.json, {Localizer localizer = const Localizer()})
      : mediaType = MediaType.fromKey(json["media_type"] as String?),
        uri = json["uri"] as String,
        title = localizer.json(json["title"]),
        caption = localizer.json(json["caption"]),
        transcript = localizer.json(json["transcript"]),
        profile = ProfileInfo.parse(json["profile"]),
        unlockId = json["unlock_id"] as String?,
        typingDelayMs = (json["typing_delay_ms"] as num?)?.toInt(),
        sfx = json["sfx"] as String?;

  @override
  MediaItemType localized(Localizer localizer) => MediaItemType.fromJson(json, localizer: localizer);

  @override
  String getType() => type;

  @override
  String? getText() => caption;

  @override
  ProfileInfo? getProfileInfo() => profile;
}
