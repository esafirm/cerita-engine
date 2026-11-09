import 'items/profile_info.dart';

class ProfileData {
  final List<Profile> profiles;

  const ProfileData(this.profiles);

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    final list = json["profiles"] as List<dynamic>;
    return ProfileData(
      list.map((item) => Profile.fromJson(item as Map<String, dynamic>)).toList(),
    );
  }
}

class Profile {
  final String id;
  final String name;
  final String avatar;
  final List<String> sprites;

  const Profile({
    required this.id,
    required this.name,
    required this.avatar,
    required this.sprites,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    final spritesList = json["sprites"] as List<dynamic>;
    return Profile(
      id: json["id"] as String,
      name: json["name"] as String,
      avatar: json["avatar"] as String,
      sprites: spritesList.map((item) => item.toString()).toList(),
    );
  }

  String getSprite(ProfileInfo info) {
    final index = int.parse(info.sprite);
    return sprites[index];
  }
}

