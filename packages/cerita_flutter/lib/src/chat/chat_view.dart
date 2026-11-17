import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../clues/case_board.dart';
import '../common/avatar.dart';
import '../common/choice_list.dart';
import '../common/input_prompt.dart';
import '../common/tagged_text.dart';
import '../l10n/story_language.dart';
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

  /// The header's status: the scene's `status` when it sets one, else the channel's, else the contact's bio.
  /// Null when there is none or the scene hides it.
  String? _status(Profile? contact) {
    final override = controller.scene.status;
    final status = override != null ? controller.localizer.resolve(override) : controller.channel?.status ?? contact?.bio;
    return status == null || status.trim().isEmpty ? null : status;
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
    final strings = StoryLanguage.of(context).strings;

    // The scene's time first, so a long status is what gets cut, never the time. No day: a messenger doesn't
    // show one, and the chapter and the story's timestamps already say it.
    final subtitle = typing != null
        ? strings.typing
        : [
            if (scene.time case final time?) strings.sceneTime(time),
            ?_status(contact),
          ].join(" · ");

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        // Room for a status that wraps onto a second line.
        toolbarHeight: 64,
        title: Row(
          children: [
            StoryAvatar(asset: avatar == null ? null : config.avatar(avatar), name: channel?.name ?? contact?.name ?? ""),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel?.name ?? contact?.name ?? strings.chat,
                    style: const TextStyle(fontSize: 17),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: strings.profile,
            icon: const Icon(Icons.person_outline),
            onPressed: contact == null ? null : () => _showProfile(context, contact),
          ),
          IconButton(tooltip: strings.gallery, icon: const Icon(Icons.photo_library_outlined), onPressed: onGallery),
          if (controller.hasClues && controller.current is! EvidenceItemType)
            IconButton(
              tooltip: strings.caseBoard,
              icon: Badge(
                isLabelVisible: controller.newClues.isNotEmpty,
                label: Text("${controller.newClues.length}"),
                child: const Icon(Icons.push_pin_outlined),
              ),
              onPressed: () => CaseBoardScreen.open(context, controller),
            ),
          IconButton(tooltip: strings.menu, icon: const Icon(Icons.more_vert), onPressed: onMenu),
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
      // The picker takes the tray's place, tall enough to browse the board.
      StoryPhase.choice when item is EvidenceItemType => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: EvidencePicker(key: ValueKey(item), controller: controller, item: item),
          ),
        ),
      StoryPhase.choice when item is ChoiceItemType => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TaggedText(item.text, style: Theme.of(context).textTheme.labelLarge),
            ),
            ChoiceList(key: ValueKey(item), item: item, paused: controller.storyHeld, onSelected: controller.choose),
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
                child: Text(StoryLanguage.of(context).strings.messageHint, style: TextStyle(color: scheme.outline)),
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
