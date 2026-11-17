import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeEngineLoader extends EngineLoader {
  final Map<String, Map<String, dynamic>> files;

  /// The story's `clues.json`, if it has one.
  final Map<String, dynamic>? clues;

  FakeEngineLoader(this.files, {this.clues});

  @override
  Future<EnginePackage> initialLoad() async => EnginePackage(
        profiles: ProfileData.fromJson({
          "profiles": [
            {"id": "nora", "name": "Nora", "sprites": ["nora.png"]},
            {"id": "miki", "name": "Miki", "sprites": ["miki.png"]},
          ],
        }),
        conversation: await loadConversation(Conversation.indexKey),
        clues: clues == null ? ClueCatalog.empty : ClueCatalog.fromJson(clues!),
      );

  @override
  Future<Conversation> loadConversation(String conversationId) async =>
      Conversation.fromJson(files[conversationId]!, key: conversationId);

  @override
  Future<List<String>> listConversationKeys() async => files.keys.toList();
}

/// The audio plugin doesn't exist in widget tests, and audioplayers keeps its init state across tests.
/// Nothing is played, the players are only created. [calls] records what would have played.
class SilentAudio extends AudioHelper {
  final calls = <String>[];

  @override
  Future<void> playBgm(String? path, {int? fadeMs}) async => calls.add("bgm $path ${fadeMs ?? "-"}");

  @override
  Future<void> playAmbience(String? path, {int? fadeMs}) async => calls.add("ambience $path ${fadeMs ?? "-"}");

  @override
  Future<void> playSfx(String path) async {}

  @override
  Future<void> playVoice(String path, {double character = 1}) async => calls.add("voice $path $character");

  @override
  Future<void> stopVoice() async {}

  @override
  Future<void> startRing(String path) async => calls.add("ring $path");

  @override
  Future<void> stopRing() async => calls.add("ring stop");

  @override
  Future<void> stopAll() async {}

  @override
  void setVolumes({required double music, required double sound, required double voice}) {}

  @override
  void duck() {}

  @override
  void unduck() {}

  @override
  void addObserver() {}

  @override
  void removeObserver() {}
}

/// Answers the plugin calls of the players [SilentAudio] creates.
void mockAudioChannels() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in ["xyz.luan/audioplayers", "xyz.luan/audioplayers.global"]) {
    messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
  }
}

