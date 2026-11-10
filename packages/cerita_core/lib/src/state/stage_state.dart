import '../data/items/profile_info.dart';
import '../data/items/sprite_position.dart';
import '../data/items/stage.dart';
import '../data/scene.dart';

/// What the VN stage shows: background, characters, music, weather and camera zoom.
/// Engine state, so a loaded save looks the way it was saved.
class StageState {
  String? background;
  String? music;
  String? weather;
  double zoom;
  SpritePosition zoomFocus;

  /// Characters by slot.
  final Map<SpritePosition, ProfileInfo> sprites;

  /// Profile id of the last speaking character. Null during narration.
  String? speakerId;

  StageState({
    this.background,
    this.music,
    this.weather,
    this.zoom = 1,
    this.zoomFocus = SpritePosition.center,
    this.speakerId,
    Map<SpritePosition, ProfileInfo>? sprites,
  }) : sprites = sprites ?? {};

  SpritePosition? slotOf(String profileId) =>
      sprites.entries.where((entry) => entry.value.id == profileId).firstOrNull?.key;

  /// Starts [scene]. Characters, weather and zoom are kept only if the background and mode stay.
  void enterScene(Scene scene, {Scene? previous}) {
    if (previous == null || scene.background != previous.background || scene.mode != previous.mode) {
      sprites.clear();
      weather = null;
      zoom = 1;
      zoomFocus = SpritePosition.center;
      speakerId = null;
    }
    background = scene.background;
    music = scene.music;
  }

  /// Puts [info] at [position], or keeps it in its current slot, or centers it.
  void place(ProfileInfo info, [SpritePosition? position]) {
    final existing = slotOf(info.id);
    if (existing != null) sprites.remove(existing);
    sprites[position ?? existing ?? SpritePosition.center] = info;
  }

  void apply(StageAction action) {
    switch (action) {
      case ShowAction(:final profile, :final position):
        place(profile, position);
      case HideAction(:final profileId):
        if (profileId == null) {
          sprites.clear();
        } else {
          sprites.removeWhere((_, info) => info.id == profileId);
        }
        if (speakerId != null && slotOf(speakerId!) == null) speakerId = null;
      case MoveAction(:final profileId, :final position):
        final existing = slotOf(profileId);
        if (existing != null) place(sprites[existing]!, position);
      case BackgroundAction(:final image):
        background = image;
      case MusicAction(:final file):
        music = file;
      case WeatherAction(:final name):
        weather = name;
      case ZoomAction(:final scale, :final focus):
        zoom = scale;
        zoomFocus = focus;
      case SoundAction() || ShakeAction() || FlashAction():
        break;
    }
  }

  factory StageState.fromJson(Map<String, dynamic> json) {
    final sprites = Map<String, dynamic>.from(json["sprites"] as Map? ?? const {});
    return StageState(
      background: json["background"] as String?,
      music: json["music"] as String?,
      weather: json["weather"] as String?,
      zoom: (json["zoom"] as num? ?? 1).toDouble(),
      zoomFocus: SpritePosition.fromName(json["zoom_focus"] as String?) ?? SpritePosition.center,
      speakerId: json["speaker"] as String?,
      sprites: {
        for (final entry in sprites.entries)
          ?SpritePosition.fromName(entry.key): ProfileInfo.fromIdentifier(entry.value as String),
      },
    );
  }

  Map<String, dynamic> toJson() => {
        "background": ?background,
        "music": ?music,
        "weather": ?weather,
        if (zoom != 1) "zoom": zoom,
        if (zoomFocus != SpritePosition.center) "zoom_focus": zoomFocus.key,
        "speaker": ?speakerId,
        "sprites": sprites.map((position, info) => MapEntry(position.key, "${info.id}:${info.spriteIndex}")),
      };
}
