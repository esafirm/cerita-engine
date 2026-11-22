import 'cast.dart';
import 'diagnostics.dart';
import 'model.dart';
import 'project.dart';

/// Asset kinds in report order (spec §3.3).
const assetKinds = [
  "background", "cg", "sprite", "avatar", "image", "video", "clue", "voice_note", "music", "ambience", "sfx", "voice",
];

/// Kinds a story can ship per locale as `name.<locale>.ext` (CE-01, data schema §5.4).
const localizedAssetKinds = {"voice", "voice_note"};

/// A file the story uses. [path] is relative to the asset folder (`bg/x.png`).
class AssetRef {
  final String kind;
  final String path;
  final SourceSpan span;

  const AssetRef(this.kind, this.path, this.span);
}

/// Every asset reference in the story, in source order.
List<AssetRef> collectAssetRefs(StoryProject project) {
  final refs = <AssetRef>[];
  final config = project.config;

  String avatarPath(String avatar) {
    if (avatar.startsWith(config.assetPrefix)) return avatar.substring(config.assetPrefix.length);
    return avatar.contains("/") ? avatar : "sprites/$avatar";
  }

  void add(String kind, String folder, Object? file, SourceSpan span) {
    if (file is! String || file.isEmpty) return;
    refs.add(AssetRef(kind, "$folder/$file", span));
  }

  for (final profile in project.cast.profiles.values) {
    final avatar = profile.avatar;
    if (avatar != null) refs.add(AssetRef("avatar", avatarPath(avatar), profile.avatarSpan ?? profile.span));
    for (var i = 0; i < profile.sprites.length; i++) {
      add("sprite", "sprites", profile.sprites[i], profile.spriteSpans[i]);
    }
  }
  for (final channel in project.channels ?? const []) {
    final avatar = channel.avatar;
    if (avatar != null) refs.add(AssetRef("avatar", avatarPath(avatar), channel.avatarSpan ?? channel.span));
  }
  for (final clue in project.clues?.clues ?? const <ClueDef>[]) {
    add("clue", "media", clue.image, clue.imageSpan ?? clue.span);
  }

  for (final conversation in project.conversations) {
    final scene = conversation.scene;
    if (scene != null) {
      add("background", "bg", scene.background, scene.span);
      add("music", "music", scene.music, scene.span);
      add("ambience", "music", scene.ambience, scene.span);
      add("sound", "music", scene.ring, scene.span);
    }
    for (final item in conversation.items) {
      switch (item) {
        case LineItem():
          add("sfx", "music", item.sfx, item.span);
          add("voice", "music", item.voice, item.span);
        case NarrationItem():
          add("sfx", "music", item.sfx, item.span);
        case MediaItem():
          final (kind, folder) = switch (item.mediaType) {
            "CG" => ("cg", "bg"),
            "AUDIO" => ("voice_note", "media"),
            "VIDEO" => ("video", "media"),
            _ => ("image", "media"),
          };
          add(kind, folder, item.uri, item.span);
          add("sfx", "music", item.sfx, item.span);
        case StageItem():
          for (final action in item.actions) {
            final file = action.fields["file"];
            switch (action.action) {
              case "background":
                add("background", "bg", action.fields["image"], action.span);
              case "cg":
                add("cg", "bg", action.fields["image"], action.span);
              case "music" || "ambience":
                add(action.action, "music", file, action.span);
              case "sound":
                add("sfx", "music", file, action.span);
            }
          }
        default:
          break;
      }
    }
  }
  return refs;
}

/// Files that are missing, first reference per path. `null` when asset checks can't run.
///
/// A voice clip or voice note is there when its shared file is, or when every locale has its own
/// `name.<locale>.ext`. Otherwise each missing per-locale file is listed, since that's what the voice pipeline
/// produces (spec §3.4).
List<AssetRef>? missingAssets(StoryProject project) {
  final files = project.assetFiles;
  if (files == null) return null;
  final locales = project.config.locales;
  final seen = <String>{};
  final missing = <AssetRef>[];
  for (final ref in collectAssetRefs(project)) {
    if (files.contains(ref.path)) continue;
    if (!localizedAssetKinds.contains(ref.kind)) {
      if (seen.add(ref.path)) missing.add(ref);
      continue;
    }
    for (final locale in locales) {
      final variant = localeVariant(ref.path, locale);
      if (!files.contains(variant) && seen.add(variant)) missing.add(AssetRef(ref.kind, variant, ref.span));
    }
  }
  return missing;
}
