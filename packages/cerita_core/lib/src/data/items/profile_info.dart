/// Parsed `<id>:<sprite_index>` profile reference. `player` refers to the player character.
class ProfileInfo {
  static const playerId = "player";

  final String id;
  final int spriteIndex;

  const ProfileInfo(this.id, [this.spriteIndex = 0]);

  factory ProfileInfo.fromIdentifier(String identifier) {
    final items = identifier.split(":");
    return ProfileInfo(items[0], items.length > 1 ? int.tryParse(items[1]) ?? 0 : 0);
  }

  static ProfileInfo? parse(dynamic identifier) =>
      identifier is String && identifier.isNotEmpty ? ProfileInfo.fromIdentifier(identifier) : null;

  bool get isPlayer => id == playerId;
}
