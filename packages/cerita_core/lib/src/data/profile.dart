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

  /// Where the face is on the sprites (`"face"`), so the stage can size every face to the character's [height]
  /// whatever the art's framing. Null takes the sprites as head to toe.
  final SpriteFace? face;

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
    this.face,
  }) : _json = null;

  Profile._fromJson(Map<String, dynamic> json, Localizer localizer)
      : id = json["id"] as String,
        name = localizer.required(json, "name"),
        handle = json["handle"] as String?,
        bio = localizer.json(json["bio"]),
        avatar = json["avatar"] as String?,
        sprites = [for (final sprite in json["sprites"] as List<dynamic>? ?? const []) sprite.toString()],
        height = (json["height"] as num?)?.toDouble(),
        face = SpriteFace.fromJson(json["face"]),
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

/// Where a character's face is on their sprites, as shares of the sprite's height from its top edge: the eye line
/// and the bottom of the chin. Measured once per character, as every pose of a character is drawn at one framing.
///
/// From it the stage knows how big the art draws the character and where their eyes are, so every face comes out
/// in proportion to the character's height (eyes to chin is about [eyeToChin] of a person's height) whether the
/// art cuts them at the knees or at the waist.
class SpriteFace {
  /// Eyes to chin, as a share of a person's height. The top of the head to the eyes is about as much again.
  static const eyeToChin = 1 / 15;

  final double eyes;
  final double chin;

  const SpriteFace({required this.eyes, required this.chin});

  static SpriteFace? fromJson(Object? json) => switch (json) {
        {"eyes": final num eyes, "chin": final num chin} => SpriteFace(eyes: eyes.toDouble(), chin: chin.toDouble()),
        _ => null,
      };

  Map<String, dynamic> toJson() => {"eyes": eyes, "chin": chin};
}
