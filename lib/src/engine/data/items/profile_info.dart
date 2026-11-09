class ProfileInfo {
  final String id;
  final String sprite;

  const ProfileInfo(this.id, this.sprite);

  factory ProfileInfo.fromIdentifier(String identifier) {
    final items = identifier.split(":");
    return ProfileInfo(items[0], items[1]);
  }
}

