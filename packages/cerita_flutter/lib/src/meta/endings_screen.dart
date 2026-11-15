import 'package:flutter/material.dart';

import '../common/ending_view.dart';
import '../l10n/story_language.dart';
import '../story_setup.dart';
import 'meta_loader.dart';

/// Endings collection: unlocked vs. total with badge, title and summary.
class EndingsScreen extends StatelessWidget {
  final StorySetup setup;

  const EndingsScreen({super.key, required this.setup});

  @override
  Widget build(BuildContext context) {
    final language = StoryLanguage.of(context);
    final strings = language.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.endings)),
      body: MetaLoader(
        setup: setup,
        builder: (context, catalog, meta) {
          final endings = [for (final entry in catalog.endings) entry.item.localized(language.localizer)];
          final unlocked = endings.where((ending) => meta.unlockedEndingIds.contains(ending.endingId)).length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(strings.endingsProgress(unlocked, endings.length), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: endings.isEmpty ? 0 : unlocked / endings.length),
              const SizedBox(height: 16),
              for (final ending in endings)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: meta.unlockedEndingIds.contains(ending.endingId)
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              EndingBadge(category: ending.category),
                              const SizedBox(height: 8),
                              Text(ending.title, style: Theme.of(context).textTheme.titleMedium),
                              if (ending.summary != null) Text(ending.summary!),
                            ],
                          )
                        : Row(
                            children: [
                              const Icon(Icons.lock_outline),
                              const SizedBox(width: 12),
                              Expanded(child: Text(strings.lockedEnding)),
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
