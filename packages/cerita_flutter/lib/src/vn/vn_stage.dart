import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../clues/case_board.dart';
import '../common/backlog_sheet.dart';
import '../common/choice_list.dart';
import '../common/input_prompt.dart';
import '../common/media_widgets.dart';
import '../common/tagged_text.dart';
import '../skin/story_skin.dart';
import '../story_controller.dart';
import '../story_setup.dart';
import 'dialogue_box.dart';
import 'nvl_page.dart';
import 'poi.dart';

/// Visual Novel stage: background, sprite slots, dialogue box or NVL page, CG overlays,
/// choice / input overlays and quick controls (backlog, auto, skip, menu, back, quick save / load, hide).
/// A mouse wheel scroll up rolls back.
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
  final _nvlKey = GlobalKey<TypewriterTextState>();

  /// The item whose line is fully shown. Choices and the input prompt wait for it, so they
  /// don't cover a question that is still being asked.
  ItemType? _typedItem;

  /// The dialogue box, overlays and controls are hidden to look at the stage.
  bool _hidden = false;

  StoryController get controller => widget.controller;

  LoaderConfig get config => widget.setup.config;

  void _onTap() {
    if (_hidden) {
      _setHidden(false);
      return;
    }
    if (_dialogueKey.currentState?.complete() ?? false) return;
    if (_nvlKey.currentState?.complete() ?? false) return;
    controller.advance();
  }

  /// The line of [item] is fully shown: choices can appear, auto mode can count, and `{nw}` lines move on.
  void _lineTyped(ItemType? item, String text) {
    if (!identical(_typedItem, item)) setState(() => _typedItem = item);
    controller.lineTyped();
    if (TextMarkup.parse(text).noWait && !controller.rolledBack && !controller.skipMode) controller.advance();
  }

  void _setHidden(bool hidden) {
    setState(() => _hidden = hidden);
    controller.setUiHidden(hidden);
  }

  @override
  void dispose() {
    // A scene change can take the stage away while the UI is hidden.
    if (_hidden) controller.setUiHidden(false);
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && event.scrollDelta.dy < 0 && !_hidden) controller.rollback();
  }

  List<PoiActor> _actors() => [
        for (final MapEntry(key: position, value: info) in controller.stage.sprites.entries)
          if (controller.profileById(info.id)?.getSprite(info) case final sprite?)
            PoiActor(id: info.id, sprite: config.sprite(sprite), position: position),
      ];

  @override
  Widget build(BuildContext context) {
    final item = controller.current;
    final scene = controller.scene;
    final stage = controller.stage;

    final (String? text, bool italic) = switch (item) {
      TextItemType(:final text) => (text, false),
      NarrationItemType(:final text) => (text, true),
      ChoiceItemType(:final text) => (text, false),
      InputItemType(:final text) => (text, false),
      WaitItemType(:final notificationText) => (notificationText, true),
      _ => (null, false),
    };

    final asked = text == null || item is MediaItemType || identical(_typedItem, item);
    // Rolled-back lines and their stage show at once, like skipped ones.
    final instant = controller.skipMode || controller.rolledBack;
    final nvl = stage.textbox == TextboxStyle.nvl;
    final msPerChar = controller.settings.value.textMsPerChar;
    final autoResume = controller.autoMode ? Duration(milliseconds: controller.settings.value.autoDelayMs) : null;
    final picking = controller.phase == StoryPhase.choice && item is EvidenceItemType && asked;

    // Top-anchored, so the bottom inset is not its concern. Above the picker it would leave a gap.
    final hud = MediaQuery.removePadding(
      context: context,
      removeBottom: true,
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
          onBack: controller.canRollback ? controller.rollback : null,
          onQuickSave: controller.replay ? null : controller.quickSave,
          onQuickLoad: controller.replay ? null : controller.quickLoad,
          onHide: () => _setHidden(true),
          onCaseBoard: controller.hasClues && item is! EvidenceItemType
              ? () => CaseBoardScreen.open(context, controller)
              : null,
          newClues: controller.newClues.length,
        ),
      ),
    );

    return Listener(
      onPointerSignal: _onPointerSignal,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Poi(
              background: stage.background == null ? null : config.bg(stage.background!),
              actors: _actors(),
              speakerId: item is NarrationItemType ? null : stage.speakerId,
              direction: controller.direction,
              zoom: stage.zoom,
              zoomFocus: stage.zoomFocus,
              weather: stage.weather,
              instant: instant,
            ),
            if (item is MediaItemType) _MediaOverlay(item: item, setup: widget.setup, controller: controller),
            // Offstage rather than removed, so the line doesn't type out again when it comes back.
            Offstage(
              offstage: _hidden,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (nvl && item is! MediaItemType)
                    NvlPage(
                      controller: controller,
                      typewriterKey: _nvlKey,
                      instant: instant,
                      msPerChar: msPerChar,
                      autoResume: autoResume,
                      onTyped: () => _lineTyped(item, item?.getText() ?? ""),
                    ),
                  if (!nvl && text != null && item is! MediaItemType)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 16,
                      child: DialogueBox(
                        text,
                        key: _dialogueKey,
                        speaker: item is NarrationItemType ? null : controller.currentProfile?.name,
                        italic: italic,
                        instant: instant,
                        msPerChar: msPerChar,
                        autoResume: autoResume,
                        onTyped: () => _lineTyped(item, text),
                      ),
                    ),
                  // The picker fills the screen, so it goes below the HUD rather than under it: the prompt and
                  // countdown stay readable, and the backlog stays at hand to look up what was said.
                  if (picking)
                    ColoredBox(
                      color: Colors.black54,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          hud,
                          Expanded(
                            child: MediaQuery.removePadding(
                              context: context,
                              removeTop: true,
                              child: SafeArea(
                                minimum: const EdgeInsets.all(16),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: EvidencePicker(key: ValueKey(item), controller: controller, item: item),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (controller.phase == StoryPhase.choice && item is ChoiceItemType && asked)
                    _Dimmed(
                      child: ChoiceList(
                        key: ValueKey(item),
                        item: item,
                        dark: true,
                        paused: controller.storyHeld,
                        onSelected: controller.choose,
                      ),
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
                  if (!picking) Positioned(top: 0, left: 0, right: 0, child: hud),
                ],
              ),
            ),
          ],
        ),
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
                  child: VoiceNotePlayer(
                    asset: path,
                    transcript: item.transcript,
                    audio: controller.audio,
                    assets: setup.assets,
                  ),
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
