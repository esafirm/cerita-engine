import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../l10n/story_language.dart';
import '../story_setup.dart';
import 'meta_loader.dart';

/// Chapter / Day timeline. The story can be continued from an unlocked checkpoint with its saved
/// variables ([onSelect]), or just that chapter replayed ([onReplay]).
class ChaptersScreen extends StatelessWidget {
  final StorySetup setup;
  final ValueChanged<Checkpoint> onSelect;

  /// Null hides the replay button.
  final ValueChanged<Checkpoint>? onReplay;

  const ChaptersScreen({super.key, required this.setup, required this.onSelect, this.onReplay});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = StoryLanguage.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(language.strings.chapters)),
      body: MetaLoader(
        setup: setup,
        builder: (context, catalog, meta) {
          final chapters = catalog.checkpoints;
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: chapters.length,
            itemBuilder: (context, index) {
              final conversation = chapters[index].localized(language.localizer);
              final checkpoint = meta.unlockedCheckpoints[conversation.key];
              final unlocked = checkpoint != null;
              return IntrinsicHeight(
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Column(
                        children: [
                          Expanded(child: VerticalDivider(color: index == 0 ? Colors.transparent : scheme.outline)),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: unlocked ? scheme.primary : scheme.surfaceContainerHighest,
                            child: unlocked
                                ? Text("${conversation.scene.day ?? index}", style: TextStyle(color: scheme.onPrimary))
                                : Icon(Icons.lock, size: 16, color: scheme.outline),
                          ),
                          Expanded(
                            child: VerticalDivider(
                              color: index == chapters.length - 1 ? Colors.transparent : scheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Card(
                        margin: const EdgeInsets.fromLTRB(0, 6, 16, 6),
                        child: ListTile(
                          enabled: unlocked,
                          title: Text(conversation.chapter ?? conversation.key),
                          subtitle: Text(unlocked ? (conversation.title ?? "") : language.strings.notReachedYet),
                          trailing: switch (onReplay) {
                            final onReplay? when unlocked => IconButton(
                                tooltip: language.strings.replayChapter,
                                icon: const Icon(Icons.replay),
                                onPressed: () => onReplay(checkpoint),
                              ),
                            _ when unlocked => const Icon(Icons.play_arrow),
                            _ => null,
                          },
                          onTap: unlocked ? () => onSelect(checkpoint) : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
