import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../story_controller.dart';

/// Scrollable backlog of the delivered transcript.
class BacklogSheet extends StatelessWidget {
  final StoryController controller;

  const BacklogSheet({super.key, required this.controller});

  static Future<void> show(BuildContext context, StoryController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(heightFactor: 0.8, child: BacklogSheet(controller: controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = controller.history.where((entry) {
      final item = entry.itemType;
      return entry.isPlayer || item is TextItemType || item is NarrationItemType || item is MediaItemType;
    }).toList();
    final theme = Theme.of(context);

    return Column(
      children: [
        Text("Backlog", style: theme.textTheme.titleLarge),
        Expanded(
          child: ListView.separated(
            reverse: true,
            padding: const EdgeInsets.all(16),
            itemCount: lines.length,
            separatorBuilder: (_, _) => const Divider(height: 20),
            itemBuilder: (context, index) {
              final entry = lines[lines.length - 1 - index];
              final item = entry.itemType;
              final speaker = entry.isPlayer
                  ? controller.profileById(ProfileInfo.playerId)?.name
                  : item == null
                      ? null
                      : controller.profileOf(item)?.name;
              final text = entry.playerText ??
                  switch (item) {
                    MediaItemType(:final mediaType, :final caption) => "[${mediaType.key}] ${caption ?? ""}",
                    _ => item?.getText() ?? "",
                  };
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (speaker != null)
                    Text(speaker, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                  Text(
                    text,
                    style: item is NarrationItemType ? const TextStyle(fontStyle: FontStyle.italic) : null,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
