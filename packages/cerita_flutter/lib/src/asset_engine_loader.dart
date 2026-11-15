import 'dart:convert';

import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/services.dart' show AssetBundle, AssetManifest, rootBundle;

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

    // clues.json is optional, but a broken one should fail loudly.
    final assets = (await AssetManifest.loadFromAssetBundle(bundle)).listAssets();
    final cluesPath = "${config.storyDir}/clues.json";
    final clues = assets.contains(cluesPath) ? ClueCatalog.fromJson(await _loadJson(cluesPath)) : ClueCatalog.empty;

    return EnginePackage(
      conversation: conversation,
      profiles: ProfileData.fromJson(profiles),
      channels: channels,
      clues: clues,
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

  /// Clears the bundle's cache. With `flutter run`, a hot reload has copied the edited files already.
  @override
  void clearCache() => bundle.clear();

  /// The bundled files, from the asset manifest.
  @override
  Future<bool Function(String path)?> assetChecker() async {
    final assets = (await AssetManifest.loadFromAssetBundle(bundle)).listAssets().toSet();
    return assets.contains;
  }

  /// `credits.json` when the bundle has it.
  @override
  Future<Credits?> loadCredits() async {
    final path = "${config.storyDir}/credits.json";
    if (!(await AssetManifest.loadFromAssetBundle(bundle)).listAssets().contains(path)) return null;
    return Credits.fromJson(await _loadJson(path));
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
