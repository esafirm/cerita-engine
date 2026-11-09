import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:fsse/src/engine/data/item_result.dart';
import 'package:fsse/src/engine/data/items/choice.dart';
import 'package:fsse/src/engine/data/items/input.dart';
import 'package:fsse/src/engine/data/scene.dart';
import 'package:fsse/src/engine/fsse_engine.dart';
import 'package:fsse/src/simpleconversation/audio_helper.dart';
import 'package:fsse/src/simpleconversation/dialogue_box.dart';
import 'package:fsse/src/simpleconversation/poi.dart';

class SimpleConversation extends StatefulWidget {
  const SimpleConversation({super.key});

  @override
  State<SimpleConversation> createState() => SimpleConversationState();
}

class SimpleConversationState extends State<SimpleConversation> implements EngineListener {
  final AudioHelper audioPlayer = AudioHelper();
  final LoaderConfig config = const LoaderConfig(musicDir: "story/music");

  late final FsseEngine engine;
  String? currentText;

  String? profileImage;
  String? backgroundImage;

  SimpleConversationState() {
    engine = RealFsseEngine.withListener(AssetEngineLoader(config), this);
  }

  @override
  void initState() {
    super.initState();
    audioPlayer.addObserver();
  }

  @override
  void dispose() {
    audioPlayer.removeObserver();
    super.dispose();
  }

  @override
  void onNewScene(Scene scene) {
    developer.log("on new bg: ${scene.background}");
    developer.log("on new music: ${scene.music}");

    audioPlayer.play("${config.musicDir}/${scene.music}");

    setState(() {
      backgroundImage = "${config.bgDir}/${scene.background}";
    });
  }

  Future<ItemResult?> getItemResult() async {
    final item = await engine.get();
    developer.log("Current item $item");

    if (item is InputItemType) {
      return ItemResult.input(item.variable, "TikTok");
    }
    if (item is ChoiceItemType) {
      final firstChoice = item.choices.first;
      return ItemResult.choice(item.variable, firstChoice.value, firstChoice.target);
    }
    return null;
  }

  Future<void> proceedToNextItem() async {
    final itemResult = await getItemResult();
    final nextItem = await engine.next(prevResult: itemResult);
    final profile = engine.getProfile(nextItem);

    developer.log("Prev result is $itemResult");
    developer.log("Next item is $nextItem");

    setState(() {
      currentText = nextItem.getText();

      if (profile != null) {
        final spriteName = profile.getSprite(nextItem.getProfileInfo()!);
        profileImage = "${config.spritesDir}/$spriteName";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPoiAvailable = backgroundImage != null || profileImage != null;

    return MaterialApp(
      theme: ThemeData(),
      home: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: InkWell(
                onTap: proceedToNextItem,
                child: Stack(
                  children: [
                    if (isPoiAvailable) Poi(backgroundImage, profileImage),
                    if (currentText != null)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: DialogueBox(currentText!),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

