import '../l10n/localized_text.dart';
import 'items/profile_info.dart';

class ProfileData {
  final List<Profile> profiles;

  const ProfileData(this.profiles);

  factory ProfileData.fromJson(Map<String, dynamic> json, {Localizer localizer = const Localizer()}) {
    final list = json["profiles"] as List<dynamic>;
    return ProfileData(
      list.map((item) => Profile.fromJson(item as Map<String, dynamic>, localizer: localizer)).toList(),
    );
  }

  Profile? byId(String id) => profiles.where((element) => element.id == id).firstOrNull;

  ProfileData localized(Localizer localizer) =>
      ProfileData([for (final profile in profiles) profile.localized(localizer)]);
}

class Profile {
  final String id;
  final String name;
  final String? handle;
  final String? bio;
  final String? avatar;
  final List<String> sprites;

  /// How tall the character is, in any unit the whole cast shares (`"height"`). Null when not given: the stage then
  /// takes them as tall as the tallest character.
  final double? height;

  /// Where the head is on the sprites (`"head"`), so the stage can size every head to the character's [height]
  /// whatever the art's framing. Null takes the sprites as head to toe.
  final SpriteHead? head;

  /// The JSON it was read from, to show it in another language. Null when built in code.
  final Map<String, dynamic>? _json;

  const Profile({
    required this.id,
    required this.name,
    this.handle,
    this.bio,
    this.avatar,
    this.sprites = const [],
    this.height,
    this.head,
  }) : _json = null;

  Profile._fromJson(Map<String, dynamic> json, Localizer localizer)
      : id = json["id"] as String,
        name = localizer.required(json, "name"),
        handle = json["handle"] as String?,
        bio = localizer.json(json["bio"]),
        avatar = json["avatar"] as String?,
        sprites = [for (final sprite in json["sprites"] as List<dynamic>? ?? const []) sprite.toString()],
        height = (json["height"] as num?)?.toDouble(),
        head = SpriteHead.fromJson(json["head"]),
        _json = json;

  factory Profile.fromJson(Map<String, dynamic> json, {Localizer localizer = const Localizer()}) =>
      Profile._fromJson(json, localizer);

  /// The same profile with [name] and [bio] in [localizer]'s language.
  Profile localized(Localizer localizer) => switch (_json) {
        final json? => Profile._fromJson(json, localizer),
        null => this,
      };

  bool get isPlayer => id == ProfileInfo.playerId;

  String? getSprite(ProfileInfo info) {
    if (sprites.isEmpty) return null;
    final index = info.spriteIndex;
    return sprites[index.clamp(0, sprites.length - 1)];
  }
}

/// Where a character's head is on their sprites, as shares of the sprite's height from its top edge: the top of the
/// hair and the bottom of the chin. Measured once per character, as every pose of a character is drawn at one
/// framing.
///
/// From it the stage knows how big the art draws the character, so every head comes out in proportion to the
/// character's height ([ofHeight] of it) whether the art cuts them at the knees or at the waist. The whole head counts,
/// hair included, because that is what the eye compares: art styles draw faces differently (big low eyes and a
/// short chin on one character, a long jaw on another), so sizing by eyes to chin alone can make one head half again
/// as big as another.
class SpriteHead {
  /// The top of the hair to the chin, as a share of the character's height: about a sixth in this style of art.
  static const ofHeight = 1 / 6;

  final double top;
  final double chin;

  const SpriteHead({required this.top, required this.chin});

  static SpriteHead? fromJson(Object? json) => switch (json) {
        {"top": final num top, "chin": final num chin} => SpriteHead(top: top.toDouble(), chin: chin.toDouble()),
        _ => null,
      };

  Map<String, dynamic> toJson() => {"top": top, "chin": chin};
}
