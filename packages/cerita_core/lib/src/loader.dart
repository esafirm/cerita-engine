import 'data/channel.dart';
import 'data/clue.dart';
import 'data/conversation.dart';
import 'data/items/media.dart';
import 'data/profile.dart';

class EnginePackage {
  final Conversation conversation;
  final ProfileData profiles;
  final List<Channel> channels;

  /// The clues of the optional `clues.json`. Empty without it.
  final ClueCatalog clues;

  const EnginePackage({
    required this.conversation,
    required this.profiles,
    this.channels = const [],
    this.clues = ClueCatalog.empty,
  });
}

abstract class EngineLoader {
  /// Loads `profiles.json`, `index.json` and the optional `channels.json` and `clues.json`.
  Future<EnginePackage> initialLoad();

  /// Loads `cvn_<conversationId>.json`, or `index.json` for [Conversation.indexKey].
  Future<Conversation> loadConversation(String conversationId);

  /// Keys of every conversation in the story. Used to build the gallery / endings catalog.
  Future<List<String>> listConversationKeys() async => const [Conversation.indexKey];

  /// Forgets cached story files, so the next loads read them again (developer reload).
  void clearCache() {}

  /// Tells whether a file (a [LoaderConfig] path) exists, for [StoryLinter.assetExists]. Null when the
  /// loader can't tell.
  Future<bool Function(String path)?> assetChecker() async => null;
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

  /// CGs live in `bg/`; photos, voice notes and videos in `media/`.
  String mediaPath(MediaItemType item) => item.mediaType == MediaType.cg ? bg(item.uri) : media(item.uri);

  /// Avatars may be full asset paths (as in the spec) or bare sprite file names.
  String avatar(String path) => path.startsWith("assets/") ? path : sprite(path);
}
