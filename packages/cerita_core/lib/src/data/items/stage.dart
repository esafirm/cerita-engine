import 'package:cerita_core/src/l10n/localized_text.dart';
import '../scene.dart';
import 'base.dart';
import 'media.dart';
import 'profile_info.dart';
import 'sprite_position.dart';

/// VN stage direction: shows / moves characters, changes the background, CG, music, weather and camera.
class StageItemType extends ItemType {
  static const type = "STAGE";

  final List<StageAction> actions;

  /// How long the story waits before moving on. Null waits for the longest action.
  final int? waitMs;

  StageItemType.fromJson(super.json)
      : actions = (json["actions"] as List<dynamic>? ?? const [])
            .map((e) => StageAction.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        waitMs = (json["wait_ms"] as num?)?.toInt();

  /// [waitMs], or the longest [StageAction.blockingMs].
  int get effectiveWaitMs =>
      waitMs ?? actions.fold(0, (longest, action) => action.blockingMs > longest ? action.blockingMs : longest);

  @override
  String getType() => type;

  @override
  String? getText() => null;
}

/// Animation used when a character or background appears, changes or leaves.
enum StageTransition {
  fade,
  dissolve,
  fadeBlack,
  slideLeft,
  slideRight,
  slideUp,
  zoom,
  wipeLeft,
  wipeRight,
  none;

  static StageTransition? fromName(String? name) {
    if (name == null) return null;
    final camel = name.replaceAllMapped(RegExp(r"_([a-z])"), (m) => m.group(1)!.toUpperCase());
    return values.where((e) => e.name == camel).firstOrNull ?? (throw Exception("Unknown transition '$name'"));
  }
}

sealed class StageAction {
  static const defaultDurationMs = 500;

  /// Null uses the skin's default transition.
  final StageTransition? transition;
  final int durationMs;

  const StageAction({this.transition, this.durationMs = defaultDurationMs});

  /// How long the story waits for this action. A [CgMoveAction] plays on under the lines that follow it.
  int get blockingMs => durationMs;

  factory StageAction.fromJson(Map<String, dynamic> json) {
    final transition = StageTransition.fromName(json["transition"] as String?);
    final duration = (json["duration_ms"] as num?)?.toInt();
    final instant = transition == StageTransition.none ? 0 : null;
    final durationMs = duration ?? instant ?? defaultDurationMs;
    final action = json["action"] as String?;

    SpritePosition? position([String key = "position"]) {
      final name = json[key] as String?;
      return name == null
          ? null
          : SpritePosition.fromName(name) ?? (throw Exception("Unknown position '$name' in $action"));
    }

    String profileId() => ProfileInfo.fromIdentifier(json["profile"] as String).id;

    return switch (action) {
      "show" => ShowAction(
          ProfileInfo.fromIdentifier(json["profile"] as String),
          position: position(),
          transition: transition,
          durationMs: durationMs,
        ),
      "hide" => HideAction(profileId(), transition: transition, durationMs: durationMs),
      "clear" => HideAction(null, transition: transition, durationMs: durationMs),
      "move" => MoveAction(profileId(), position()!, durationMs: durationMs),
      "background" => BackgroundAction(json["image"] as String?, transition: transition, durationMs: durationMs),
      "cg" => CgAction(
          json["image"] as String?,
          unlockId: json["unlock_id"] as String?,
          title: LocalizedText.fromJson(json["title"]),
          caption: LocalizedText.fromJson(json["caption"]),
          zoom: (json["zoom"] as num?)?.toDouble(),
          focus: CgFocus.fromName(json["focus"] as String?),
          transition: transition,
          durationMs: durationMs,
        ),
      "cg_move" => CgMoveAction(
          zoom: (json["zoom"] as num?)?.toDouble(),
          focus: CgFocus.fromName(json["focus"] as String?),
          durationMs: durationMs,
        ),
      "music" => MusicAction(json["file"] as String?, fadeMs: (json["fade_ms"] as num?)?.toInt()),
      "ambience" => AmbienceAction(json["file"] as String?, fadeMs: (json["fade_ms"] as num?)?.toInt()),
      "textbox" => TextboxAction(
          TextboxStyle.fromName(json["style"] as String?) ??
              (throw Exception("Unknown textbox style '${json["style"]}', use 'adv' or 'nvl'")),
        ),
      "page" => const PageAction(),
      "sound" => SoundAction(json["file"] as String),
      "weather" => WeatherAction(json["name"] as String?),
      "shake" => ShakeAction(intensity: (json["intensity"] as num? ?? 10).toDouble(), durationMs: duration ?? 400),
      "flash" => FlashAction(color: json["color"] as String? ?? "#FFFFFF", durationMs: duration ?? 400),
      "zoom" => ZoomAction(
          scale: (json["scale"] as num? ?? 1).toDouble(),
          focus: position("focus") ?? SpritePosition.center,
          durationMs: durationMs,
        ),
      _ => throw Exception("Unknown stage action '$action'"),
    };
  }
}

/// Shows a character, or changes the expression / slot of one already on stage.
class ShowAction extends StageAction {
  final ProfileInfo profile;
  final SpritePosition? position;

  const ShowAction(this.profile, {this.position, super.transition, super.durationMs});
}

/// Removes the character [profileId], or every character when null.
class HideAction extends StageAction {
  final String? profileId;

  const HideAction(this.profileId, {super.transition, super.durationMs});
}

class MoveAction extends StageAction {
  final String profileId;
  final SpritePosition position;

  const MoveAction(this.profileId, this.position, {super.durationMs});
}

class BackgroundAction extends StageAction {
  /// Null shows black.
  final String? image;

  const BackgroundAction(this.image, {super.transition, super.durationMs});
}

class MusicAction extends StageAction {
  /// Null stops the music.
  final String? file;

  /// Fade between the old and the new track. Null uses the player's default.
  final int? fadeMs;

  const MusicAction(this.file, {this.fadeMs}) : super(durationMs: 0);
}

/// Changes the looping background sound.
class AmbienceAction extends StageAction {
  /// Null stops it.
  final String? file;
  final int? fadeMs;

  const AmbienceAction(this.file, {this.fadeMs}) : super(durationMs: 0);
}

/// Switches between the dialogue box and the NVL page.
class TextboxAction extends StageAction {
  final TextboxStyle style;

  const TextboxAction(this.style) : super(durationMs: 0);
}

/// Starts a new NVL page.
class PageAction extends StageAction {
  const PageAction() : super(durationMs: 0);
}

class SoundAction extends StageAction {
  final String file;

  const SoundAction(this.file) : super(durationMs: 0);
}

class WeatherAction extends StageAction {
  /// `rain`, `snow`, `sakura`, or null to clear.
  final String? name;

  const WeatherAction(this.name) : super(durationMs: 0);
}

class ShakeAction extends StageAction {
  final double intensity;

  const ShakeAction({this.intensity = 10, super.durationMs});
}

class FlashAction extends StageAction {
  /// `#RRGGBB`.
  final String color;

  const FlashAction({this.color = "#FFFFFF", super.durationMs});
}

class ZoomAction extends StageAction {
  final double scale;
  final SpritePosition focus;

  const ZoomAction({this.scale = 1, this.focus = SpritePosition.center, super.durationMs});
}

/// Where a CG's camera points: the part of the image kept in view when the CG is cropped to the screen or zoomed.
enum CgFocus {
  center(0, 0),
  left(-1, 0),
  right(1, 0),
  top(0, -1),
  bottom(0, 1),
  topLeft(-1, -1),
  topRight(1, -1),
  bottomLeft(-1, 1),
  bottomRight(1, 1);

  /// Alignment from -1 (left / top) to 1 (right / bottom).
  final double x;
  final double y;

  const CgFocus(this.x, this.y);

  /// `snake_case` name, as in the story JSON.
  String get key => name.replaceAllMapped(RegExp(r"[A-Z]"), (m) => "_${m.group(0)!.toLowerCase()}");

  static CgFocus? fromName(String? name) =>
      name == null ? null : values.where((e) => e.key == name).firstOrNull ?? (throw Exception("Unknown focus '$name'"));
}

/// Shows a full-screen CG over the stage, or swaps it for another (a variant of the same moment), or with a null
/// [image] takes it away. Unlike a `MEDIA` CG it stays while the lines after it play, until the next `cg`, a
/// `cg` with no image, or a new scene.
class CgAction extends StageAction {
  /// File in `bg/`. Null hides the CG.
  final String? image;

  /// Registers the CG in the Gallery.
  final String? unlockId;

  /// Gallery name and caption of an unlockable CG, like a `MEDIA` CG's `title` and `caption`.
  final LocalizedText? title;
  final LocalizedText? caption;

  /// Camera the CG starts with: [zoom] (default `1`) towards [focus] (default [CgFocus.center]). A variant swapped
  /// in for the CG shown keeps the camera where it is unless these are given.
  final double? zoom;
  final CgFocus? focus;

  const CgAction(
    this.image, {
    this.unlockId,
    this.title,
    this.caption,
    this.zoom,
    this.focus,
    super.transition,
    super.durationMs,
  });

  /// The CG as a Gallery entry, when it has an [unlockId], with its text in [localizer]'s language. It keeps the
  /// raw text, so [MediaItemType.localized] shows it in another language.
  MediaItemType? galleryItem({Localizer localizer = const Localizer()}) => unlockId == null || image == null
      ? null
      : MediaItemType.fromJson({
          "type": MediaItemType.type,
          "media_type": MediaType.cg.key,
          "uri": image,
          "unlock_id": unlockId,
          "title": ?title?.toJson(),
          "caption": ?caption?.toJson(),
        }, localizer: localizer);
}

/// Moves the camera on the CG shown: zooms to [zoom] and pans to [focus] over [durationMs], a slow pan or push-in.
/// The story doesn't wait for it, so the move plays on under the lines that follow.
class CgMoveAction extends StageAction {
  /// Null keeps the current zoom / focus.
  final double? zoom;
  final CgFocus? focus;

  const CgMoveAction({this.zoom, this.focus, super.durationMs});

  @override
  int get blockingMs => 0;
}
