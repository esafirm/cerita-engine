import 'diagnostics.dart';
import 'model.dart';
import 'project.dart';

/// Asset kinds in report order (spec §3.3).
const assetKinds = ["background", "cg", "sprite", "avatar", "image", "video", "voice_note", "music", "sfx", "voice"];

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

  void add(String kind, String folder, String? file, SourceSpan span) {
    if (file == null || file.isEmpty) return;
    refs.add(AssetRef(kind, "$folder/$file", span));
  }

  void addAll(String kind, String folder, LocalizedAsset? asset) {
    if (asset == null) return;
    for (final file in asset.files(config.locales, config.sourceLocale)) {
      add(kind, folder, file, asset.span);
    }
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

  for (final conversation in project.conversations) {
    final scene = conversation.scene;
    if (scene != null) {
      add("background", "bg", scene.background, scene.span);
      add("music", "music", scene.music, scene.span);
    }
    for (final item in conversation.items) {
      switch (item) {
        case LineItem():
          add("sfx", "music", item.sfx, item.span);
          addAll("voice", "music", item.voice);
        case NarrationItem():
          add("sfx", "music", item.sfx, item.span);
        case MediaItem():
          final (kind, folder) = switch (item.mediaType) {
            "CG" => ("cg", "bg"),
            "AUDIO" => ("voice_note", "media"),
            "VIDEO" => ("video", "media"),
            _ => ("image", "media"),
          };
          addAll(kind, folder, item.uri);
          add("sfx", "music", item.sfx, item.span);
        default:
          break;
      }
    }
  }
  return refs;
}

/// References whose file isn't in the asset folder, first reference per path. `null` when asset checks can't run.
List<AssetRef>? missingAssets(StoryProject project) {
  final files = project.assetFiles;
  if (files == null) return null;
  final seen = <String>{};
  return [
    for (final ref in collectAssetRefs(project))
      if (!files.contains(ref.path) && seen.add(ref.path)) ref,
  ];
}
