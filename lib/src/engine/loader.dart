import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, AssetManifest, rootBundle;

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

class AssetEngineLoader extends EngineLoader {
  static const String _prefixConversation = "cvn_";

  final LoaderConfig config;
  final AssetBundle bundle;

  AssetEngineLoader(this.config, {AssetBundle? bundle}) : bundle = bundle ?? rootBundle;

  Future<Map<String, dynamic>> _loadJson(String path) async =>
      jsonDecode(await bundle.loadString(path)) as Map<String, dynamic>;

  @override
  Future<EnginePackage> initialLoad() async {
    final profiles = await _loadJson("${config.storyDir}/profiles.json");
    final conversation = await loadConversation(Conversation.indexKey);

    List<Channel> channels = const [];
    try {
      channels = Channel.listFromJson(await _loadJson("${config.storyDir}/channels.json"));
    } catch (_) {
      // channels.json is optional
    }

    return EnginePackage(
      conversation: conversation,
      profiles: ProfileData.fromJson(profiles),
      channels: channels,
    );
  }

  @override
  Future<Conversation> loadConversation(String conversationId) async {
    final key = conversationId.startsWith(_prefixConversation)
        ? conversationId.substring(_prefixConversation.length)
        : conversationId;
    final file = key == Conversation.indexKey ? "index.json" : "$_prefixConversation$key.json";
    return Conversation.fromJson(await _loadJson("${config.storyDir}/$file"), key: key);
  }

  @override
  Future<List<String>> listConversationKeys() async {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    final prefix = "${config.storyDir}/$_prefixConversation";
    final keys = manifest
        .listAssets()
        .where((path) => path.startsWith(prefix) && path.endsWith(".json"))
        .map((path) => path.substring(prefix.length, path.length - ".json".length))
        .toList()
      ..sort();
    return [Conversation.indexKey, ...keys];
  }
}
