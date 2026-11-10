import 'package:cerita_core/src/data/items/profile_info.dart';

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

/// Photo, voice note, video or full-screen CG. [unlockId] registers it in the Gallery.
class MediaItemType extends ItemType {
  static const type = "MEDIA";

  final MediaType mediaType;
  final String uri;
  final String? caption;
  final String? transcript;
  final ProfileInfo? profile;
  final String? unlockId;
  final int? typingDelayMs;
  final String? sfx;

  MediaItemType.fromJson(super.json)
      : mediaType = MediaType.fromKey(json["media_type"] as String?),
        uri = json["uri"] as String,
        caption = json["caption"] as String?,
        transcript = json["transcript"] as String?,
        profile = ProfileInfo.parse(json["profile"]),
        unlockId = json["unlock_id"] as String?,
        typingDelayMs = (json["typing_delay_ms"] as num?)?.toInt(),
        sfx = json["sfx"] as String?;

  @override
  String getType() => type;

  @override
  String? getText() => caption;

  @override
  ProfileInfo? getProfileInfo() => profile;
}
