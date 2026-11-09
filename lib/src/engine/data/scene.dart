class Scene {
  final String background;
  final String music;

  const Scene({required this.background, required this.music});

  factory Scene.fromJson(Map<String, dynamic> json) {
    return Scene(
      background: json["background"] as String,
      music: json["music"] as String,
    );
  }
}

