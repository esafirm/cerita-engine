import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../audio_helper.dart';
import '../common/media_widgets.dart';
import '../l10n/story_language.dart';
import '../story_setup.dart';
import 'meta_loader.dart';

/// Collectibles gallery: photos & CGs, voice notes and videos. Locked items show their unlock hint. Only the kinds
/// the story has get a tab, and a story with a single kind shows it without tabs.
class GalleryScreen extends StatelessWidget {
  final StorySetup setup;

  /// The story's audio, ducked while a voice note plays. Null outside a story: the voice note then plays at the
  /// player's voice volume on its own.
  final AudioHelper? audio;

  const GalleryScreen({super.key, required this.setup, this.audio});

  @override
  Widget build(BuildContext context) {
    final strings = StoryLanguage.of(context).strings;
    final kinds = [
      (strings.photosAndCgs, Icons.photo_outlined, {MediaType.image, MediaType.cg}),
      (strings.voiceNotes, Icons.mic_none, {MediaType.audio}),
      (strings.videos, Icons.videocam_outlined, {MediaType.video}),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(strings.gallery)),
      body: MetaLoader(
        setup: setup,
        builder: (context, catalog, meta) {
          final tabs = [
            for (final (label, icon, types) in kinds)
              if (catalog.media.where((entry) => types.contains(entry.item.mediaType)).toList() case final entries
                  when entries.isNotEmpty)
                (label, icon, entries),
          ];
          Widget grid(String label, List<CatalogEntry<MediaItemType>> entries, {bool titled = false}) => _GalleryGrid(
                setup: setup,
                audio: audio,
                entries: entries,
                unlocked: meta.unlockedMediaIds,
                title: titled ? label : null,
              );

          if (tabs.isEmpty) return _Empty(strings.galleryEmpty);
          if (tabs.length == 1) return grid(tabs.single.$1, tabs.single.$3, titled: true);
          return DefaultTabController(
            length: tabs.length,
            child: Column(
              children: [
                TabBar(tabs: [for (final (label, icon, _) in tabs) Tab(text: label, icon: Icon(icon))]),
                Expanded(child: TabBarView(children: [for (final (label, _, entries) in tabs) grid(label, entries)])),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;

  const _Empty(this.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 48, color: scheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: scheme.outline)),
          ],
        ),
      ),
    );
  }
}

class _GalleryGrid extends StatelessWidget {
  final StorySetup setup;
  final AudioHelper? audio;
  final List<CatalogEntry<MediaItemType>> entries;
  final Set<String> unlocked;

  /// The kind of the entries, shown above them when there are no tabs to name it.
  final String? title;

  const _GalleryGrid({required this.setup, required this.entries, required this.unlocked, this.audio, this.title});

  @override
  Widget build(BuildContext context) {
    final language = StoryLanguage.of(context);
    final count = entries.where((entry) => unlocked.contains(entry.item.unlockId)).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              if (title != null) Text(title!, style: Theme.of(context).textTheme.titleSmall),
              Text(language.strings.galleryProgress(count, entries.length)),
            ],
          ),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(12),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (final entry in entries)
                unlocked.contains(entry.item.unlockId)
                    ? _UnlockedTile(setup: setup, audio: audio, item: entry.item.localized(language.localizer))
                    : _LockedTile(hint: language.strings.unlockedIn(_chapterOf(entry.source, language.localizer))),
            ],
          ),
        ),
      ],
    );
  }
}

/// Where a locked item is found, e.g. "Day 1".
String _chapterOf(Conversation source, Localizer localizer) =>
    localizer.maybe(source.chapterText) ?? localizer.maybe(source.titleText) ?? source.key;

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
  final AudioHelper? audio;
  final MediaItemType item;

  const _UnlockedTile({required this.setup, required this.item, this.audio});

  @override
  Widget build(BuildContext context) {
    final path = setup.mediaPath(item);
    final scheme = Theme.of(context).colorScheme;

    final (Widget preview, VoidCallback onTap) = switch (item.mediaType) {
      MediaType.image || MediaType.cg => (
          Image.asset(path, fit: BoxFit.cover),
          () => ImageViewerPage.open(context, path, caption: item.caption, from: context),
        ),
      MediaType.audio => (
          ColoredBox(color: scheme.primaryContainer, child: Icon(Icons.graphic_eq, size: 48, color: scheme.primary)),
          () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  content: VoiceNotePlayer(
                    asset: path,
                    transcript: item.transcript,
                    audio: audio,
                    volume: setup.settings.value.voiceVolume,
                    assets: setup.assets,
                  ),
                ),
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
              if (item.title ?? item.caption ?? item.transcript case final label?)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      label,
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
