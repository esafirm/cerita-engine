import 'data/channel.dart';
import 'data/conversation.dart';
import 'data/profile.dart';

class EnginePackage {
  final Conversation conversation;
  final ProfileData profiles;
  final List<Channel> channels;

  const EnginePackage({required this.conversation, required this.profiles, this.channels = const []});
}

abstract class EngineLoader {
  /// Loads `profiles.json`, `index.json` and the optional `channels.json`.
  Future<EnginePackage> initialLoad();

  /// Loads `cvn_<conversationId>.json`, or `index.json` for [Conversation.indexKey].
  Future<Conversation> loadConversation(String conversationId);

  /// Keys of every conversation in the story. Used to build the gallery / endings catalog.
  Future<List<String>> listConversationKeys() async => const [Conversation.indexKey];
}

class LoaderConfig {
  final String storyDir;
  final String musicDir;
  final String spritesDir;
  final String bgDir;
  final String mediaDir;

  const LoaderConfig({
    this.storyDir = "assets/story",
    this.musicDir = "assets/story/music",
    this.spritesDir = "assets/story/sprites",
    this.bgDir = "assets/story/bg",
    this.mediaDir = "assets/story/media",
  });

  String bg(String name) => "$bgDir/$name";

  String sprite(String name) => "$spritesDir/$name";

  String music(String name) => "$musicDir/$name";

  String media(String name) => "$mediaDir/$name";

  /// Avatars may be full asset paths (as in the spec) or bare sprite file names.
  String avatar(String path) => path.startsWith("assets/") ? path : sprite(path);
}
