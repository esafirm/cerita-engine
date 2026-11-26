import 'dart:convert';

import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/services.dart' show AssetBundle, AssetManifest, rootBundle;

class AssetEngineLoader extends EngineLoader {
  static const String _prefixConversation = "cvn_";

  final LoaderConfig config;
  final AssetBundle bundle;
  Future<Set<String>>? _manifestAssets;

  AssetEngineLoader(this.config, {AssetBundle? bundle}) : bundle = bundle ?? rootBundle;

  Future<Map<String, dynamic>> _loadJson(String path) async =>
      jsonDecode(await bundle.loadString(path)) as Map<String, dynamic>;

  Future<Set<String>> _assets() =>
      _manifestAssets ??= AssetManifest.loadFromAssetBundle(bundle).then((manifest) => manifest.listAssets().toSet());

  @override
  Future<EnginePackage> initialLoad() async {
    final profiles = await _loadJson("${config.storyDir}/profiles.json");
    final conversation = await loadConversation(Conversation.indexKey);
    final assets = await _assets();

    // channels.json and clues.json are optional, but broken ones should fail loudly.
    final channelsPath = "${config.storyDir}/channels.json";
    final channels = assets.contains(channelsPath) ? Channel.listFromJson(await _loadJson(channelsPath)) : const <Channel>[];

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
  void clearCache() {
    _manifestAssets = null;
    bundle.clear();
  }

  /// The bundled files, from the asset manifest.
  @override
  Future<bool Function(String path)?> assetChecker() async {
    final assets = await _assets();
    return assets.contains;
  }

  /// `credits.json` when the bundle has it.
  @override
  Future<Credits?> loadCredits() async {
    final path = "${config.storyDir}/credits.json";
    if (!(await _assets()).contains(path)) return null;
    return Credits.fromJson(await _loadJson(path));
  }

  @override
  Future<List<String>> listConversationKeys() async {
    final assets = await _assets();
    final prefix = "${config.storyDir}/$_prefixConversation";
    final keys = assets
        .where((path) => path.startsWith(prefix) && path.endsWith(".json"))
        .map((path) => path.substring(prefix.length, path.length - ".json".length))
        .toList()
      ..sort();
    return [Conversation.indexKey, ...keys];
  }
}
