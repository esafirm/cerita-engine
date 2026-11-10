import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../common/backlog_sheet.dart';
import '../common/choice_list.dart';
import '../common/input_prompt.dart';
import '../common/media_widgets.dart';
import '../skin/story_skin.dart';
import '../story_controller.dart';
import '../story_setup.dart';
import 'dialogue_box.dart';
import 'poi.dart';

/// Visual Novel stage: background, sprite slots, dialogue box, CG overlays,
/// choice / input overlays and quick controls (backlog, auto, skip, menu).
class VnStage extends StatefulWidget {
  final StoryController controller;
  final StorySetup setup;
  final VoidCallback onMenu;

  const VnStage({super.key, required this.controller, required this.setup, required this.onMenu});

  @override
  State<VnStage> createState() => _VnStageState();
}

class _VnStageState extends State<VnStage> {
  final _dialogueKey = GlobalKey<DialogueBoxState>();

  /// The item whose line is fully shown. Choices and the input prompt wait for it, so they
  /// don't cover a question that is still being asked.
  ItemType? _typedItem;

  StoryController get controller => widget.controller;

  LoaderConfig get config => widget.setup.config;

  void _onTap() {
    if (_dialogueKey.currentState?.complete() ?? false) return;
    controller.advance();
  }

  Map<SpritePosition, String> _sprites() {
    final sprites = <SpritePosition, String>{};
    controller.stage.forEach((position, info) {
      final sprite = controller.profileById(info.id)?.getSprite(info);
      if (sprite != null) sprites[position] = config.sprite(sprite);
    });
    return sprites;
  }

  @override
  Widget build(BuildContext context) {
    final item = controller.current;
    final scene = controller.scene;
    final speakerSlot = controller.stage.entries.where((e) => e.value.id == controller.speakerId).firstOrNull?.key;

    final (String? text, bool italic) = switch (item) {
      TextItemType(:final text) => (text, false),
      NarrationItemType(:final text) => (text, true),
      ChoiceItemType(:final text) => (text, false),
      InputItemType(:final text) => (text, false),
      WaitItemType(:final notificationText) => (notificationText, true),
      _ => (null, false),
    };

    final asked = text == null || item is MediaItemType || identical(_typedItem, item);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Poi(
            background: scene.background == null ? null : config.bg(scene.background!),
            sprites: _sprites(),
            speaker: item is NarrationItemType ? null : speakerSlot,
          ),
          if (item is MediaItemType) _MediaOverlay(item: item, setup: widget.setup, controller: controller),
          if (text != null && item is! MediaItemType)
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: DialogueBox(
                text,
                key: _dialogueKey,
                speaker: item is NarrationItemType ? null : controller.currentProfile?.name,
                italic: italic,
                instant: controller.skipMode,
                onTyped: () {
                  if (!identical(_typedItem, item)) setState(() => _typedItem = item);
                },
              ),
            ),
          if (controller.phase == StoryPhase.choice && item is ChoiceItemType && asked)
            _Dimmed(
              child: ChoiceList(key: ValueKey(item), item: item, dark: true, onSelected: controller.choose),
            ),
          if (controller.phase == StoryPhase.input && item is InputItemType && asked)
            _Dimmed(
              liftAboveKeyboard: true,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: InputPrompt(item: item, onSubmit: controller.submitInput),
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: StorySkin.of(context).vnHud(
              context,
              VnHud(
                label: scene.day != null || scene.time != null
                    ? [
                        if (controller.conversation?.chapter != null) controller.conversation!.chapter!,
                        if (scene.time != null) scene.time!,
                      ].join(" · ")
                    : null,
                autoMode: controller.autoMode,
                skipMode: controller.skipMode,
                onBacklog: () => BacklogSheet.show(context, controller),
                onAuto: controller.toggleAuto,
                onSkip: controller.toggleSkip,
                onMenu: widget.onMenu,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dimmed extends StatelessWidget {
  final Widget child;

  /// Keeps [child] clear of the keyboard. The stage itself is not resized for it.
  final bool liftAboveKeyboard;

  const _Dimmed({required this.child, this.liftAboveKeyboard = false});

  @override
  Widget build(BuildContext context) {
    final keyboard = liftAboveKeyboard ? MediaQuery.viewInsetsOf(context).bottom : 0.0;
    return ColoredBox(
      color: Colors.black54,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboard),
        child: Center(child: Padding(padding: const EdgeInsets.all(24), child: child)),
      ),
    );
  }
}

/// CG / photo full-screen overlay, or a centered card for voice notes and videos.
class _MediaOverlay extends StatelessWidget {
  final MediaItemType item;
  final StorySetup setup;
  final StoryController controller;

  const _MediaOverlay({required this.item, required this.setup, required this.controller});

  @override
  Widget build(BuildContext context) {
    final path = setup.mediaPath(item);
    final caption = item.caption;
    return Stack(
      fit: StackFit.expand,
      children: [
        switch (item.mediaType) {
          MediaType.cg || MediaType.image => TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
              child: ColoredBox(
                color: Colors.black,
                child: Image.asset(path, fit: item.mediaType == MediaType.cg ? BoxFit.cover : BoxFit.contain),
              ),
            ),
          MediaType.audio => _Dimmed(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: VoiceNotePlayer(asset: path, transcript: item.transcript, audio: controller.audio),
                ),
              ),
            ),
          MediaType.video => _Dimmed(
              child: SizedBox(width: 200, child: VideoPreview(asset: path, caption: caption, audio: controller.audio)),
            ),
        },
        if (caption != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
              child: Text(caption, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
      ],
    );
  }
}
