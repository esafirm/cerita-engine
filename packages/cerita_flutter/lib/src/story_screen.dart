import 'dart:async';

import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import 'call/call_view.dart';
import 'chat/chat_view.dart';
import 'clues/case_board.dart';
import 'common/backlog_sheet.dart';
import 'common/ending_view.dart';
import 'common/story_sheet.dart';
import 'l10n/story_language.dart';
import 'meta/developer_sheet.dart';
import 'meta/endings_screen.dart';
import 'meta/gallery_screen.dart';
import 'meta/save_slots_screen.dart';
import 'meta/settings_screen.dart';
import 'scene_switcher.dart';
import 'skin/chapter_card_overlay.dart';
import 'story_controller.dart';
import 'story_setup.dart';
import 'vn/vn_stage.dart';

/// Plays a story and switches presentation mode whenever the scene changes.
/// With [replay], only the [checkpoint]'s chapter is played and nothing is saved.
class StoryScreen extends StatefulWidget {
  final StorySetup setup;
  final SaveSlot? save;
  final Checkpoint? checkpoint;
  final bool replay;

  const StoryScreen({super.key, required this.setup, this.save, this.checkpoint, this.replay = false});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  late final StoryController _controller = StoryController(
    loader: widget.setup.loader,
    storage: widget.setup.storage,
    config: widget.setup.config,
    settings: widget.setup.settings,
    audio: widget.setup.audio(),
    assets: widget.setup.assets,
  );
  StreamSubscription<String>? _toasts;
  Object? _error;
  bool _started = false;

  /// Rolled after the endings they name (CE-08).
  Credits? _credits;

  @override
  void initState() {
    super.initState();
    widget.setup.loader.loadCredits().then((credits) {
      if (mounted) setState(() => _credits = credits);
    }, onError: (Object _) {});
    _toasts = _controller.toasts.listen((message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Runs again whenever the player switches language.
    _controller.setLanguage(StoryLanguage.of(context));
    if (_started) return;
    _started = true;
    _controller
        .start(save: widget.save, checkpoint: widget.checkpoint, replay: widget.replay)
        .catchError((Object error) {
      if (mounted) setState(() => _error = error);
    });
  }

  /// A Flutter hot reload has copied edited story files: read them again.
  @override
  void reassemble() {
    super.reassemble();
    _controller.reloadStory();
  }

  @override
  void dispose() {
    _toasts?.cancel();
    _controller.audio.stopAll();
    _controller.dispose();
    super.dispose();
  }

  void _openGallery() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GalleryScreen(setup: widget.setup)));

  void _openMenu() {
    final strings = StoryLanguage.of(context).strings;
    StorySheet.show<void>(
      context,
      title: strings.menu,
      icon: Icons.menu,
      builder: (sheetContext) {
        void close(VoidCallback action) {
          Navigator.of(sheetContext).pop();
          action();
        }

        void push(WidgetBuilder builder) =>
            close(() => Navigator.of(context).push(MaterialPageRoute(builder: builder)));

        // The main actions as big buttons, the rest as a list, and leaving the story set apart at the end.
        final actions = [
          if (!_controller.replay)
            StorySheetAction(
              icon: Icons.save_outlined,
              label: strings.saveGame,
              onTap: () => push((_) => SaveSlotsScreen(setup: widget.setup, onSave: _controller.saveTo)),
            ),
          StorySheetAction(
            icon: Icons.folder_open,
            label: strings.loadGame,
            onTap: () => push(
              (route) => SaveSlotsScreen(
                setup: widget.setup,
                onLoad: (save) {
                  Navigator.of(route).pop();
                  _controller.load(save);
                },
              ),
            ),
          ),
          if (_controller.hasClues && _controller.current is! EvidenceItemType)
            StorySheetAction(
              icon: Icons.push_pin_outlined,
              label: strings.caseBoard,
              badge: _controller.newClues.length,
              onTap: () => close(() => CaseBoardScreen.open(context, _controller)),
            ),
          StorySheetAction(
            icon: Icons.history,
            label: strings.backlog,
            onTap: () => close(() => BacklogSheet.show(context, _controller)),
          ),
        ];
        // Scrolls on short or landscape screens.
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [for (final action in actions) Expanded(child: action)],
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.tune),
                title: Text(strings.settings),
                onTap: () => push((_) => SettingsScreen(settings: widget.setup.settings, loader: widget.setup.loader)),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(strings.gallery),
                onTap: () => close(_openGallery),
              ),
              ListTile(
                leading: const Icon(Icons.emoji_events_outlined),
                title: Text(strings.endings),
                onTap: () => push((_) => EndingsScreen(setup: widget.setup)),
              ),
              ListTile(
                leading: const Icon(Icons.data_object),
                title: Text(strings.storyVariables),
                onTap: () => close(_showVariables),
              ),
              if (widget.setup.developer)
                ListTile(
                  leading: const Icon(Icons.build_outlined),
                  title: Text(strings.developer),
                  onTap: () => close(() => DeveloperSheet.show(context, _controller, widget.setup)),
                ),
              const Divider(height: 16),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: Text(strings.backToTitle),
                onTap: () => close(() => Navigator.of(context).pop()),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Debug view of the typed state store, handy to see effects at work.
  void _showVariables() {
    final data = _controller.dataMap;
    final strings = StoryLanguage.of(context).strings;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.storyVariables),
        content: data.isEmpty
            ? Text(strings.noVariables)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in data.entries)
                    ListTile(
                      dense: true,
                      title: Text(entry.key, style: const TextStyle(fontFamily: "monospace")),
                      trailing: Text("${entry.value}"),
                    ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      final message = StoryLanguage.of(context).strings.loadError(_error!);
      return Scaffold(appBar: AppBar(), body: Center(child: Text(message)));
    }

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final controller = _controller;
        final mode = controller.scene.mode;
        final view = switch (mode) {
          SceneMode.vn => VnStage(controller: controller, setup: widget.setup, onMenu: _openMenu),
          SceneMode.chat => ChatView(
              controller: controller,
              setup: widget.setup,
              onMenu: _openMenu,
              onGallery: _openGallery,
            ),
          SceneMode.call => CallView(controller: controller, setup: widget.setup, onMenu: _openMenu),
        };
        final ending = controller.current;

        return Scaffold(
          backgroundColor: Colors.black,
          // The keyboard must not squeeze the stage. Chat resizes its own Scaffold, and the VN input
          // prompt moves itself above the keyboard.
          resizeToAvoidBottomInset: false,
          body: ClueNotifications(
            controller: controller,
            child: Stack(
              fit: StackFit.expand,
              children: [
                SceneSwitcher(
                  mode: mode,
                  scene: (
                    channelId: controller.scene.channelId,
                    // A new VN conversation is a new scene. Chat and call threads continue across conversations.
                    conversationKey: mode == SceneMode.vn ? controller.conversation?.key : null,
                  ),
                  // The card belongs to its scene, so it leaves with the outgoing one.
                  child: switch (controller.conversation) {
                    final conversation? => ChapterCardOverlay(conversation: conversation, child: view),
                    null => view,
                  },
                ),
                if (controller.notification != null)
                  Positioned(
                    top: 0,
                    left: 12,
                    right: 12,
                    child: SafeArea(child: _NotificationBanner(text: controller.notification!)),
                  ),
                if (controller.phase == StoryPhase.ending && ending is EndingItemType)
                  EndingView(
                    ending: ending,
                    credits: _credits,
                    onEndings: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => EndingsScreen(setup: widget.setup)),
                    ),
                    onTitle: () => Navigator.of(context).pop(),
                  ),
                if (controller.phase == StoryPhase.finished)
                  controller.replay
                      ? EndingView(
                          title: StoryLanguage.of(context).strings.endOfReplay,
                          backLabel: StoryLanguage.of(context).strings.back,
                          onTitle: () => Navigator.of(context).pop(),
                        )
                      : EndingView(onTitle: () => Navigator.of(context).pop()),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NotificationBanner extends StatelessWidget {
  final String text;

  const _NotificationBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -80, end: 8),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, offset, child) => Transform.translate(offset: Offset(0, offset), child: child),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          leading: const Icon(Icons.notifications_active),
          title: const Text("Cerita", style: TextStyle(fontSize: 12)),
          subtitle: Text(text, style: const TextStyle(fontSize: 15)),
        ),
      ),
    );
  }
}
