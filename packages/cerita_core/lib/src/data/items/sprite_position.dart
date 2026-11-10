/// VN sprite slots, left to right.
enum SpritePosition {
  farLeft("far_left"),
  left("left"),
  center("center"),
  right("right"),
  farRight("far_right");

  final String key;

  const SpritePosition(this.key);

  static SpritePosition? fromName(String? name) => values.where((e) => e.key == name).firstOrNull;
}
