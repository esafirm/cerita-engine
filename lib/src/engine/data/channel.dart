/// Messenger thread metadata from the optional `channels.json`.
class Channel {
  final String id;
  final String name;
  final String? avatar;
  final String? status;
  final List<String> members;

  const Channel({required this.id, required this.name, this.avatar, this.status, this.members = const []});

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json["id"] as String,
      name: json["name"] as String,
      avatar: json["avatar"] as String?,
      status: json["status"] as String?,
      members: (json["members"] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
    );
  }

  static List<Channel> listFromJson(Map<String, dynamic> json) {
    final list = json["channels"] as List<dynamic>? ?? const [];
    return list.map((e) => Channel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
