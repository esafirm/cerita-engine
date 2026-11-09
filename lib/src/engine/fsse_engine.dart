import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/services.dart' show rootBundle;
import 'package:fsse/src/engine/data/item_result.dart';
import 'package:fsse/src/engine/data/profile.dart';

import 'data/conversation.dart';
import 'data/items/base.dart';
import 'data/scene.dart';

class EnginePackage {
  final Conversation conversation;
  final ProfileData profiles;

  const EnginePackage({required this.conversation, required this.profiles});

  factory EnginePackage.fromJsonFiles(Map<String, dynamic> profiles, Map<String, dynamic> conversation) {
    return EnginePackage(
      conversation: Conversation.fromJson(conversation),
      profiles: ProfileData.fromJson(profiles),
    );
  }
}

abstract class EngineLoader {
  Future<EnginePackage> initialLoad();

  Future<Conversation> loadConversation(String conversationId);
}

abstract class FsseEngine {
  /// Proceed to next item. You can provide the previous result of item type
  /// This result object can have a data that will be stored in data map
  /// or will load next conversation
  Future<ItemType> next({ItemResult? prevResult});

  /// Get current item of item type.
  Future<ItemType> get();

  /// Get data map from engine container map
  Map<String, dynamic> getDataMap();

  /// Get profile for item type
  Profile? getProfile(ItemType itemType);
}

abstract class EngineListener {
  /// Called when new scene (background and or music) is available
  void onNewScene(Scene scene);
}

class LoaderConfig {
  final String storyDir;
  final String musicDir;
  final String spritesDir;
  final String bgDir;

  const LoaderConfig({
    this.storyDir = "assets/story",
    this.musicDir = "assets/story/music",
    this.spritesDir = "assets/story/sprites",
    this.bgDir = "assets/story/bg",
  });
}

/* Impl */
/* ------------------------------------------ */

class AssetEngineLoader extends EngineLoader {
  final LoaderConfig config;

  static const String _prefixConversation = "cvn_";

  AssetEngineLoader(this.config);

  @override
  Future<EnginePackage> initialLoad() async {
    final profileString = await rootBundle.loadString("${config.storyDir}/profiles.json");
    final conversationString = await rootBundle.loadString("${config.storyDir}/index.json");

    return EnginePackage.fromJsonFiles(
      jsonDecode(profileString) as Map<String, dynamic>,
      jsonDecode(conversationString) as Map<String, dynamic>,
    );
  }

  @override
  Future<Conversation> loadConversation(String conversationId) async {
    final newConversation = await rootBundle.loadString("${config.storyDir}/$_prefixConversation$conversationId.json");
    return Conversation.fromJson(jsonDecode(newConversation) as Map<String, dynamic>);
  }
}

class RealFsseEngine extends FsseEngine {
  static const _tag = "FSSE";

  final EngineLoader loader;
  final EngineListener? listener;

  RealFsseEngine(this.loader) : listener = null;

  RealFsseEngine.withListener(this.loader, this.listener);

  late ProfileData profileData;

  Conversation? currentConversation;
  int dialogIndex = 0;

  final Map<String, String> dataMap = {};

  @override
  Future<ItemType> next({ItemResult? prevResult}) async {
    developer.log("Request next with index: $dialogIndex", name: _tag);

    await _loadPackageIfNeeded();
    await _handleResult(prevResult);

    final result = await _getCurrentItemType();
    dialogIndex += 1;
    return result;
  }

  @override
  Future<ItemType> get() async {
    developer.log("Request get with index: $dialogIndex", name: _tag);
    await _loadPackageIfNeeded();
    return _getCurrentItemType();
  }

  @override
  Map<String, dynamic> getDataMap() => dataMap;

  @override
  Profile? getProfile(ItemType itemType) {
    final info = itemType.getProfileInfo();
    if (info == null) {
      return null;
    }
    return profileData.profiles.where((element) => element.id == info.id).firstOrNull;
  }

  Future<ItemType> _getCurrentItemType() {
    final conversation = currentConversation;
    if (conversation == null) {
      return Future.error(Exception("Empty conversation. Are you already load the assets?"));
    }

    if (dialogIndex >= conversation.conversations.length) {
      return Future.error(Exception("End of conversations"));
    }

    final newData = conversation.conversations[dialogIndex].cloneWithData(dataMap);
    return Future.value(newData);
  }

  Future<void> _handleResult(ItemResult? itemResult) async {
    if (itemResult == null) return;

    // Handle data map
    if (itemResult.variable != null) {
      if (itemResult.value == null) {
        throw Exception("Variable exits but value is null");
      }
      dataMap[itemResult.variable!] = itemResult.value!;
    }

    // Handle target
    final target = itemResult.target;
    if (target != null) {
      final conversation = await loader.loadConversation(target);
      _onNewConversation(conversation);
      dialogIndex = 0;
    }
  }

  Future<bool> _loadPackageIfNeeded() async {
    if (currentConversation == null) {
      final package = await loader.initialLoad();
      profileData = package.profiles;
      _onNewConversation(package.conversation);

      developer.log("Package loaded", name: _tag);
      return true;
    }
    return false;
  }

  /// This is called after initial load
  /// and after new conversation is loaded
  void _onNewConversation(Conversation conversation) {
    currentConversation = conversation;
    listener?.onNewScene(conversation.scene);
  }
}

