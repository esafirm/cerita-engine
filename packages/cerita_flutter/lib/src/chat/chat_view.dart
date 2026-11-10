import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../common/avatar.dart';
import '../common/choice_list.dart';
import '../common/input_prompt.dart';
import '../skin/chapter_card_overlay.dart';
import '../story_controller.dart';
import '../story_setup.dart';
import 'message_bubble.dart';

/// Messenger mode: thread app bar, scrollable timeline, typing indicator and
/// an interaction tray (continue / choice cards / text composer).
class ChatView extends StatelessWidget {
  final StoryController controller;
  final StorySetup setup;
  final VoidCallback onMenu;
  final VoidCallback onGallery;

  const ChatView({
    super.key,
    required this.controller,
    required this.setup,
    required this.onMenu,
    required this.onGallery,
  });

  /// The thread's contact: first channel member, else the latest incoming speaker.
  Profile? _contact(List<TranscriptEntry> entries) {
    final memberId = controller.channel?.members.firstOrNull;
    if (memberId != null) return controller.profileById(memberId);
    for (final entry in entries.reversed) {
      final item = entry.itemType;
      final profile = item == null ? null : controller.profileOf(item);
      if (profile != null && !profile.isPlayer) return profile;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scene = controller.scene;
    final entries = controller.channelHistory(scene.channelId).where(MessageBubble.isVisible).toList();
    final contact = _contact(entries);
    final channel = controller.channel;
    final config = setup.config;
    final avatar = channel?.avatar ?? contact?.avatar;
    final typing = controller.phase == StoryPhase.typing ? controller.typingProfile : null;

    final subtitle = typing != null
        ? "typing…"
        : [
            if (scene.day != null) "Day ${scene.day}",
            scene.time,
            channel?.status ?? contact?.bio,
          ].whereType<String>().join(" · ");

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            StoryAvatar(asset: avatar == null ? null : config.avatar(avatar), name: channel?.name ?? contact?.name ?? ""),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(channel?.name ?? contact?.name ?? "Chat", style: const TextStyle(fontSize: 17)),
                  Text(subtitle, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Profile",
            icon: const Icon(Icons.person_outline),
            onPressed: contact == null ? null : () => _showProfile(context, contact),
          ),
          IconButton(tooltip: "Gallery", icon: const Icon(Icons.photo_library_outlined), onPressed: onGallery),
          IconButton(tooltip: "Menu", icon: const Icon(Icons.more_vert), onPressed: onMenu),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            // The thread moves on by itself (see StoryController's chat pacing), so no tap to continue.
            child: _PacingGate(
              controller: controller,
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                itemCount: entries.length + (typing != null ? 1 : 0),
                itemBuilder: (context, index) {
                  if (typing != null) {
                    if (index == 0) return TypingBubble(profile: typing, setup: setup);
                    index -= 1;
                  }
                  final entryIndex = entries.length - 1 - index;
                  final entry = entries[entryIndex];
                  return MessageBubble(
                    key: ValueKey(entryIndex),
                    entry: entry,
                    controller: controller,
                    setup: setup,
                    showSender: entryIndex == 0 || !MessageBubble.sameSender(entries[entryIndex - 1], entry),
                  );
                },
              ),
            ),
          ),
          _InteractionTray(controller: controller),
        ],
      ),
    );
  }

  void _showProfile(BuildContext context, Profile profile) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: StoryAvatar(
          asset: profile.avatar == null ? null : setup.config.avatar(profile.avatar!),
          name: profile.name,
          radius: 44,
        ),
        title: Text(profile.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (profile.handle != null) Text(profile.handle!, style: const TextStyle(color: Colors.grey)),
            if (profile.bio != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(profile.bio!)),
          ],
        ),
      ),
    );
  }
}

class _InteractionTray extends StatelessWidget {
  final StoryController controller;

  const _InteractionTray({required this.controller});

  @override
  Widget build(BuildContext context) {
    final item = controller.current;
    final scheme = Theme.of(context).colorScheme;
    final child = switch (controller.phase) {
      StoryPhase.choice when item is ChoiceItemType => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(item.text, style: Theme.of(context).textTheme.labelLarge),
            ),
            ChoiceList(key: ValueKey(item), item: item, onSelected: controller.choose),
          ],
        ),
      StoryPhase.input when item is InputItemType => InputPrompt(
          key: ValueKey(item),
          item: item,
          onSubmit: controller.submitInput,
        ),
      // Nothing to answer yet: an inactive composer, like a real messenger.
      _ => Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text("Message", style: TextStyle(color: scheme.outline)),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: null, icon: const Icon(Icons.send)),
          ],
        ),
    };

    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.bottomCenter,
          child: Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 10), child: child),
        ),
      ),
    );
  }
}

/// Pauses the thread's pacing while a chapter card covers it.
class _PacingGate extends StatefulWidget {
  final StoryController controller;
  final Widget child;

  const _PacingGate({required this.controller, required this.child});

  @override
  State<_PacingGate> createState() => _PacingGateState();
}

class _PacingGateState extends State<_PacingGate> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.holdPacing(ChapterCardOverlay.holdsDialogue(context));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
