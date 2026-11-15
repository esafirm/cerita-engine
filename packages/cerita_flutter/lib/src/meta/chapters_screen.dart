import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../l10n/story_language.dart';
import '../story_setup.dart';
import 'route_flowchart.dart';

/// Chapter / Day timeline, as a flowchart of the story's routes or as a list (CE-07). The flowchart is the
/// default when the story branches. The story can be continued from an unlocked checkpoint with its saved
/// variables ([onSelect]), or just that chapter replayed ([onReplay]).
class ChaptersScreen extends StatefulWidget {
  final StorySetup setup;
  final ValueChanged<Checkpoint> onSelect;

  /// Null hides the replay button.
  final ValueChanged<Checkpoint>? onReplay;

  const ChaptersScreen({super.key, required this.setup, required this.onSelect, this.onReplay});

  @override
  State<ChaptersScreen> createState() => _ChaptersScreenState();
}

class _ChaptersScreenState extends State<ChaptersScreen> {
  late final Future<(StoryCatalog, GlobalMetaState, RouteMap)> _data = _load();

  /// The view the player picked. Null until they switch.
  bool? _flowchart;

  Future<(StoryCatalog, GlobalMetaState, RouteMap)> _load() async {
    final catalog = await StoryCatalog.load(widget.setup.loader);
    return (catalog, await widget.setup.storage.loadMeta(), RouteMap(StoryGraph(catalog.conversations)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = StoryLanguage.of(context).strings;
    return FutureBuilder(
      future: _data,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final flowchart = _flowchart ?? data?.$3.branches ?? false;
        return Scaffold(
          appBar: AppBar(
            title: Text(strings.chapters),
            actions: [
              if (data != null)
                IconButton(
                  tooltip: flowchart ? strings.showList : strings.showFlowchart,
                  icon: Icon(flowchart ? Icons.view_list_outlined : Icons.account_tree_outlined),
                  onPressed: () => setState(() => _flowchart = !flowchart),
                ),
            ],
          ),
          body: switch (data) {
            _ when snapshot.hasError => Center(child: Text("${snapshot.error}")),
            null => const Center(child: CircularProgressIndicator()),
            (_, final meta, final map) when flowchart =>
              RouteFlowchart(map: map, meta: meta, onSelect: widget.onSelect, onReplay: widget.onReplay),
            (final catalog, final meta, _) => _list(context, catalog, meta),
          },
        );
      },
    );
  }

  Widget _list(BuildContext context, StoryCatalog catalog, GlobalMetaState meta) {
    final scheme = Theme.of(context).colorScheme;
    final language = StoryLanguage.of(context);
    final chapters = catalog.checkpoints;
    final onReplay = widget.onReplay;
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
                    onTap: unlocked ? () => widget.onSelect(checkpoint) : null,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
