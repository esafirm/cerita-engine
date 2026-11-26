import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../l10n/story_language.dart';
import '../skin/story_skin.dart';
import '../story_controller.dart';
import 'story_sheet.dart';
import 'tagged_text.dart';

/// Scrollable backlog of the delivered transcript. Lines that can be rolled back to have a rewind button,
/// and voiced lines a button to play their voice again.
class BacklogSheet extends StatelessWidget {
  final StoryController controller;

  const BacklogSheet({super.key, required this.controller});

  /// Opens the backlog in a [StorySheet]: as tall as its lines, up to most of the screen.
  static Future<void> show(BuildContext context, StoryController controller) async {
    controller.holdStory(true);
    try {
      await StorySheet.show<void>(
        context,
        title: StoryLanguage.of(context).strings.backlog,
        icon: Icons.history,
        builder: (_) => BacklogSheet(controller: controller),
      );
    } finally {
      Future<void>.microtask(() => controller.holdStory(false));
    }
  }

  @override
  Widget build(BuildContext context) {
    // With their transcript index, which rollback uses.
    final lines = controller.history.indexed.where((line) {
      final (_, entry) = line;
      final item = controller.itemOf(entry);
      return entry.isPlayer || item is TextItemType || item is NarrationItemType || item is MediaItemType;
    }).toList();
    final theme = Theme.of(context);
    final strings = StoryLanguage.of(context).strings;

    // Short backlogs shrink to fit the sheet; long ones fill the sheet anyway and virtualize.
    return ListView.separated(
      reverse: true,
      shrinkWrap: lines.length <= 20,
      padding: const EdgeInsets.all(16),
      itemCount: lines.length,
      separatorBuilder: (_, _) => const Divider(height: 20),
      itemBuilder: (context, index) {
        final (historyIndex, entry) = lines[lines.length - 1 - index];
        final item = controller.itemOf(entry);
        final speaker = entry.isPlayer
            ? controller.profileById(ProfileInfo.playerId)?.name
            : item == null
            ? null
            : controller.profileOf(item)?.name;
        final text =
            controller.playerTextOf(entry) ??
            switch (item) {
              MediaItemType(:final mediaType, :final caption) => "[${mediaType.key}] ${caption ?? ""}",
              _ => item?.getText() ?? "",
            };
        final line = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (speaker != null)
              Text(speaker, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
            TaggedText(text, style: item is NarrationItemType ? StorySkin.of(context).narrationStyle : null),
          ],
        );
        final voiced = item is TextItemType && item.voice != null;
        final rewind = controller.canRollbackTo(historyIndex);
        if (!voiced && !rewind) return line;
        return Row(
          children: [
            Expanded(child: line),
            if (voiced)
              IconButton(
                tooltip: strings.playVoice,
                icon: const Icon(Icons.volume_up_outlined),
                onPressed: () => controller.replayVoice(item),
              ),
            if (rewind)
              IconButton(
                tooltip: strings.rollbackToLine,
                icon: const Icon(Icons.fast_rewind_outlined),
                onPressed: () {
                  Navigator.of(context).pop();
                  controller.rollback(historyIndex: historyIndex);
                },
              ),
          ],
        );
      },
    );
  }
}
