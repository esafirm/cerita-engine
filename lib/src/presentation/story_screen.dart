import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fsse/fsse.dart';

import 'call/call_view.dart';
import 'chat/chat_view.dart';
import 'common/backlog_sheet.dart';
import 'common/ending_view.dart';
import 'meta/endings_screen.dart';
import 'meta/gallery_screen.dart';
import 'meta/save_slots_screen.dart';
import 'story_controller.dart';
import 'story_setup.dart';
import 'vn/vn_stage.dart';

/// Plays a story and switches presentation mode whenever the scene changes.
class StoryScreen extends StatefulWidget {
  final StorySetup setup;
  final SaveSlot? save;
  final Checkpoint? checkpoint;

  const StoryScreen({super.key, required this.setup, this.save, this.checkpoint});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  late final StoryController _controller = StoryController(
    loader: widget.setup.loader,
    storage: widget.setup.storage,
    config: widget.setup.config,
  );
  StreamSubscription<String>? _toasts;
  Object? _error;

  @override
  void initState() {
    super.initState();
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
    _controller.start(save: widget.save, checkpoint: widget.checkpoint).catchError((Object error) {
      if (mounted) setState(() => _error = error);
    });
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
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        void close(VoidCallback action) {
          Navigator.of(sheetContext).pop();
          action();
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.save_outlined),
                title: const Text("Save game"),
                onTap: () => close(() => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SaveSlotsScreen(setup: widget.setup, onSave: _controller.saveTo),
                    ))),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text("Backlog"),
                onTap: () => close(() => BacklogSheet.show(context, _controller)),
              ),
              ListTile(
                leading: const Icon(Icons.data_object),
                title: const Text("Story variables"),
                onTap: () => close(_showVariables),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text("Gallery"),
                onTap: () => close(_openGallery),
              ),
              ListTile(
                leading: const Icon(Icons.emoji_events_outlined),
                title: const Text("Endings"),
                onTap: () => close(() => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => EndingsScreen(setup: widget.setup)),
                    )),
              ),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text("Back to title"),
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
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Story variables"),
        content: data.isEmpty
            ? const Text("No variables yet.")
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
      return Scaffold(appBar: AppBar(), body: Center(child: Text("Can't load the story:\n$_error")));
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
          body: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                // The outgoing mode must not catch taps meant for the incoming one.
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [for (final child in previous) IgnorePointer(child: child), ?current],
                ),
                child: KeyedSubtree(key: ValueKey("${mode.key}-${controller.scene.channelId}"), child: view),
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
                  onEndings: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => EndingsScreen(setup: widget.setup)),
                  ),
                  onTitle: () => Navigator.of(context).pop(),
                ),
              if (controller.phase == StoryPhase.finished)
                EndingView(onTitle: () => Navigator.of(context).pop()),
            ],
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
