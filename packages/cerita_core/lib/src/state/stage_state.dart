import '../data/items/profile_info.dart';
import '../data/items/sprite_position.dart';
import '../data/items/stage.dart';
import '../data/scene.dart';

/// What the VN stage shows: background, characters, CG, music, ambience, weather, camera zoom and the text box.
/// Engine state, so a loaded save looks the way it was saved.
class StageState {
  String? background;
  String? music;
  String? ambience;
  String? weather;
  double zoom;
  SpritePosition zoomFocus;

  /// CG over the stage, a file in `bg/`, and the camera on it. See [CgAction].
  String? cg;
  double cgZoom;
  CgFocus cgFocus;

  /// Characters by slot.
  final Map<SpritePosition, ProfileInfo> sprites;

  /// Profile id of the last speaking character. Null during narration.
  String? speakerId;

  TextboxStyle textbox;

  /// Transcript index where the NVL page starts. The engine sets it, see [startsPage].
  int pageStart;

  StageState({
    this.background,
    this.music,
    this.ambience,
    this.weather,
    this.zoom = 1,
    this.zoomFocus = SpritePosition.center,
    this.cg,
    this.cgZoom = 1,
    this.cgFocus = CgFocus.center,
    this.speakerId,
    this.textbox = TextboxStyle.adv,
    this.pageStart = 0,
    Map<SpritePosition, ProfileInfo>? sprites,
  }) : sprites = sprites ?? {};

  SpritePosition? slotOf(String profileId) =>
      sprites.entries.where((entry) => entry.value.id == profileId).firstOrNull?.key;

  /// Starts [scene]. Characters, weather and zoom are kept only if the background and mode stay. A CG belongs to
  /// the moment it shows, so it never carries into the next scene.
  void enterScene(Scene scene, {Scene? previous}) {
    _showCg(null);
    if (previous == null || scene.background != previous.background || scene.mode != previous.mode) {
      sprites.clear();
      weather = null;
      zoom = 1;
      zoomFocus = SpritePosition.center;
      speakerId = null;
    }
    background = scene.background;
    music = scene.music;
    ambience = scene.ambience;
    textbox = scene.textbox;
  }

  /// Whether applying [action] starts a new NVL page.
  bool startsPage(StageAction action) => switch (action) {
        PageAction() => true,
        TextboxAction(:final style) => style == TextboxStyle.nvl && textbox != TextboxStyle.nvl,
        _ => false,
      };

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
      case CgAction(:final image, :final zoom, :final focus):
        _showCg(image, zoom: zoom, focus: focus);
      case CgMoveAction(:final zoom, :final focus):
        if (zoom != null) cgZoom = zoom;
        if (focus != null) cgFocus = focus;
      case MusicAction(:final file):
        music = file;
      case AmbienceAction(:final file):
        ambience = file;
      case TextboxAction(:final style):
        textbox = style;
      case WeatherAction(:final name):
        weather = name;
      case ZoomAction(:final scale, :final focus):
        zoom = scale;
        zoomFocus = focus;
      case SoundAction() || ShakeAction() || FlashAction() || PageAction():
        break;
    }
  }

  /// A CG shown over none starts centered and unzoomed, unless [zoom] / [focus] say otherwise. A variant swapped in
  /// for the CG shown keeps its camera, so the two line up while they cross-fade.
  void _showCg(String? image, {double? zoom, CgFocus? focus}) {
    final fresh = cg == null || image == null;
    cg = image;
    cgZoom = zoom ?? (fresh ? 1 : cgZoom);
    cgFocus = focus ?? (fresh ? CgFocus.center : cgFocus);
  }

  factory StageState.fromJson(Map<String, dynamic> json) {
    final sprites = Map<String, dynamic>.from(json["sprites"] as Map? ?? const {});
    return StageState(
      background: json["background"] as String?,
      music: json["music"] as String?,
      ambience: json["ambience"] as String?,
      weather: json["weather"] as String?,
      zoom: (json["zoom"] as num? ?? 1).toDouble(),
      zoomFocus: SpritePosition.fromName(json["zoom_focus"] as String?) ?? SpritePosition.center,
      cg: json["cg"] as String?,
      cgZoom: (json["cg_zoom"] as num? ?? 1).toDouble(),
      cgFocus: CgFocus.fromName(json["cg_focus"] as String?) ?? CgFocus.center,
      speakerId: json["speaker"] as String?,
      textbox: TextboxStyle.fromName(json["textbox"] as String?) ?? TextboxStyle.adv,
      pageStart: (json["page_start"] as num?)?.toInt() ?? 0,
      sprites: {
        for (final entry in sprites.entries)
          ?SpritePosition.fromName(entry.key): ProfileInfo.fromIdentifier(entry.value as String),
      },
    );
  }

  Map<String, dynamic> toJson() => {
        "background": ?background,
        "music": ?music,
        "ambience": ?ambience,
        "weather": ?weather,
        if (zoom != 1) "zoom": zoom,
        if (zoomFocus != SpritePosition.center) "zoom_focus": zoomFocus.key,
        "cg": ?cg,
        if (cgZoom != 1) "cg_zoom": cgZoom,
        if (cgFocus != CgFocus.center) "cg_focus": cgFocus.key,
        "speaker": ?speakerId,
        if (textbox != TextboxStyle.adv) "textbox": textbox.name,
        if (pageStart != 0) "page_start": pageStart,
        "sprites": sprites.map((position, info) => MapEntry(position.key, "${info.id}:${info.spriteIndex}")),
      };
}
