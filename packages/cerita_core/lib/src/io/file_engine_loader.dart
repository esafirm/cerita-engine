import 'dart:convert';
import 'dart:io';

import '../data/channel.dart';
import '../data/clue.dart';
import '../data/conversation.dart';
import '../data/profile.dart';
import '../loader.dart';

/// Loads a story folder from disk: `index.json`, `profiles.json`, the optional `channels.json` and `clues.json`,
/// and the `cvn_*.json` files. [config] points at the folder and its `bg/`, `sprites/`, `music/` and `media/`.
class FileEngineLoader extends EngineLoader {
  static const _prefix = "cvn_";

  final LoaderConfig config;

  FileEngineLoader(this.config);

  /// The story in [directory], with its asset folders inside it.
  factory FileEngineLoader.directory(String directory) {
    final dir = directory.endsWith("/") ? directory.substring(0, directory.length - 1) : directory;
    return FileEngineLoader(LoaderConfig(
      storyDir: dir,
      musicDir: "$dir/music",
      spritesDir: "$dir/sprites",
      bgDir: "$dir/bg",
      mediaDir: "$dir/media",
    ));
  }

  Future<Map<String, dynamic>> _json(String name) async =>
      jsonDecode(await File("${config.storyDir}/$name").readAsString()) as Map<String, dynamic>;

  @override
  Future<EnginePackage> initialLoad() async {
    final channels = File("${config.storyDir}/channels.json").existsSync()
        ? Channel.listFromJson(await _json("channels.json"))
        : const <Channel>[];
    final clues = File("${config.storyDir}/clues.json").existsSync()
        ? ClueCatalog.fromJson(await _json("clues.json"))
        : ClueCatalog.empty;
    return EnginePackage(
      profiles: ProfileData.fromJson(await _json("profiles.json")),
      conversation: await loadConversation(Conversation.indexKey),
      channels: channels,
      clues: clues,
    );
  }

  @override
  Future<Conversation> loadConversation(String conversationId) async {
    final key = conversationId.startsWith(_prefix) ? conversationId.substring(_prefix.length) : conversationId;
    final file = key == Conversation.indexKey ? "index.json" : "$_prefix$key.json";
    return Conversation.fromJson(await _json(file), key: key);
  }

  @override
  Future<List<String>> listConversationKeys() async {
    final keys = [
      for (final name in Directory(config.storyDir).listSync().whereType<File>().map((file) => _name(file.path)))
        if (name.startsWith(_prefix) && name.endsWith(".json")) name.substring(_prefix.length, name.length - ".json".length),
    ]..sort();
    return [Conversation.indexKey, ...keys];
  }

  static String _name(String path) => path.split(Platform.pathSeparator).last;

  @override
  Future<bool Function(String path)?> assetChecker() async => exists;

  /// For [StoryLinter.assetExists]. App asset paths (`assets/...`, as avatars may use) are read from the
  /// app folder that holds [LoaderConfig.storyDir].
  bool exists(String path) {
    final storyDir = config.storyDir;
    final assets = storyDir.startsWith("assets/") ? 0 : storyDir.indexOf("/assets/") + 1;
    final appPath = path.startsWith("assets/") && assets > 0 && !path.startsWith(storyDir)
        ? "${storyDir.substring(0, assets)}$path"
        : path;
    return File(appPath).existsSync();
  }
}
