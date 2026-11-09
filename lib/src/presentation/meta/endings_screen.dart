import 'package:flutter/material.dart';

import '../common/ending_view.dart';
import '../story_setup.dart';
import 'meta_loader.dart';

/// Endings collection: unlocked vs. total with badge, title and summary.
class EndingsScreen extends StatelessWidget {
  final StorySetup setup;

  const EndingsScreen({super.key, required this.setup});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Endings")),
      body: MetaLoader(
        setup: setup,
        builder: (context, catalog, meta) {
          final endings = catalog.endings;
          final unlocked = endings.where((entry) => meta.unlockedEndingIds.contains(entry.item.endingId)).length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text("$unlocked / ${endings.length} endings", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: endings.isEmpty ? 0 : unlocked / endings.length),
              const SizedBox(height: 16),
              for (final entry in endings)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: meta.unlockedEndingIds.contains(entry.item.endingId)
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              EndingBadge(category: entry.item.category),
                              const SizedBox(height: 8),
                              Text(entry.item.title, style: Theme.of(context).textTheme.titleMedium),
                              if (entry.item.summary != null) Text(entry.item.summary!),
                            ],
                          )
                        : const Row(
                            children: [
                              Icon(Icons.lock_outline),
                              SizedBox(width: 12),
                              Text("??? — keep playing to discover this ending"),
                            ],
                          ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
