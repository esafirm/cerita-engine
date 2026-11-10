import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../story_setup.dart';
import 'meta_loader.dart';

/// Chapter / Day timeline. Unlocked checkpoints can be replayed with their saved variables.
class ChaptersScreen extends StatelessWidget {
  final StorySetup setup;
  final ValueChanged<Checkpoint> onSelect;

  const ChaptersScreen({super.key, required this.setup, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text("Chapters")),
      body: MetaLoader(
        setup: setup,
        builder: (context, catalog, meta) {
          final chapters = catalog.checkpoints;
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: chapters.length,
            itemBuilder: (context, index) {
              final conversation = chapters[index];
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
                          subtitle: Text(unlocked ? (conversation.title ?? "") : "Not reached yet"),
                          trailing: unlocked ? const Icon(Icons.play_arrow) : null,
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
