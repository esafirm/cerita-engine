import 'base.dart';
import 'profile_info.dart';
import 'sprite_position.dart';

/// VN stage direction: shows / moves characters, changes the background, music, weather and camera.
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

  /// [waitMs], or the duration of the longest action.
  int get effectiveWaitMs => waitMs ?? actions.fold(0, (longest, action) => action.durationMs > longest ? action.durationMs : longest);

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
      "music" => MusicAction(json["file"] as String?),
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

  const MusicAction(this.file) : super(durationMs: 0);
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
