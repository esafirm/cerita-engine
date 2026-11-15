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

  /// The JSON it was read from, to show it in another language. Null when built in code.
  final Map<String, dynamic>? _json;

  const Profile({
    required this.id,
    required this.name,
    this.handle,
    this.bio,
    this.avatar,
    this.sprites = const [],
  }) : _json = null;

  Profile._fromJson(Map<String, dynamic> json, Localizer localizer)
      : id = json["id"] as String,
        name = localizer.required(json, "name"),
        handle = json["handle"] as String?,
        bio = localizer.json(json["bio"]),
        avatar = json["avatar"] as String?,
        sprites = [for (final sprite in json["sprites"] as List<dynamic>? ?? const []) sprite.toString()],
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
