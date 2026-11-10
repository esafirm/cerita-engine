import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../common/media_widgets.dart';
import '../story_setup.dart';
import 'meta_loader.dart';

/// Collectibles gallery: photos & CGs, voice notes and videos. Locked items show their unlock hint.
class GalleryScreen extends StatelessWidget {
  final StorySetup setup;

  const GalleryScreen({super.key, required this.setup});

  static const _tabs = [
    ("Photos & CGs", Icons.photo_outlined, {MediaType.image, MediaType.cg}),
    ("Voice notes", Icons.mic_none, {MediaType.audio}),
    ("Videos", Icons.videocam_outlined, {MediaType.video}),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Gallery"),
          bottom: TabBar(tabs: [for (final (label, icon, _) in _tabs) Tab(text: label, icon: Icon(icon))]),
        ),
        body: MetaLoader(
          setup: setup,
          builder: (context, catalog, meta) => TabBarView(
            children: [
              for (final (_, _, types) in _tabs)
                _GalleryGrid(
                  setup: setup,
                  entries: catalog.media.where((entry) => types.contains(entry.item.mediaType)).toList(),
                  unlocked: meta.unlockedMediaIds,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryGrid extends StatelessWidget {
  final StorySetup setup;
  final List<CatalogEntry<MediaItemType>> entries;
  final Set<String> unlocked;

  const _GalleryGrid({required this.setup, required this.entries, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final count = entries.where((entry) => unlocked.contains(entry.item.unlockId)).length;
    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(12), child: Text("$count / ${entries.length} unlocked")),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(12),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (final entry in entries)
                unlocked.contains(entry.item.unlockId)
                    ? _UnlockedTile(setup: setup, item: entry.item)
                    : _LockedTile(hint: entry.hint),
            ],
          ),
        ),
      ],
    );
  }
}

class _LockedTile extends StatelessWidget {
  final String hint;

  const _LockedTile({required this.hint});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 36, color: scheme.outline),
          const SizedBox(height: 8),
          Text(hint, textAlign: TextAlign.center, style: TextStyle(color: scheme.outline, fontSize: 12)),
        ],
      ),
    );
  }
}

class _UnlockedTile extends StatelessWidget {
  final StorySetup setup;
  final MediaItemType item;

  const _UnlockedTile({required this.setup, required this.item});

  @override
  Widget build(BuildContext context) {
    final path = setup.mediaPath(item);
    final scheme = Theme.of(context).colorScheme;

    final (Widget preview, VoidCallback onTap) = switch (item.mediaType) {
      MediaType.image || MediaType.cg => (
          Image.asset(path, fit: BoxFit.cover),
          () => ImageViewerPage.open(context, path, caption: item.caption),
        ),
      MediaType.audio => (
          ColoredBox(color: scheme.primaryContainer, child: Icon(Icons.graphic_eq, size: 48, color: scheme.primary)),
          () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(content: VoiceNotePlayer(asset: path, transcript: item.transcript)),
              ),
        ),
      MediaType.video => (
          const ColoredBox(color: Color(0xFF1B2440), child: Icon(Icons.play_circle_outline, size: 48, color: Colors.white)),
          () => VideoPlayerPage.open(context, path, caption: item.caption),
        ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              preview,
              if (item.caption != null || item.transcript != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      item.caption ?? item.transcript!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
