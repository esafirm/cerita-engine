import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../l10n/cerita_strings.dart';
import '../l10n/story_language.dart';
import '../story_setup.dart';
import '../vn/poi.dart';

/// Lists the autosave, quick save and manual slots. Saves when [onSave] is set, loads via [onLoad] otherwise.
class SaveSlotsScreen extends StatefulWidget {
  static const manualSlots = [1, 2, 3];

  final StorySetup setup;
  final Future<void> Function(int slotId)? onSave;
  final ValueChanged<SaveSlot>? onLoad;

  const SaveSlotsScreen({super.key, required this.setup, this.onSave, this.onLoad});

  @override
  State<SaveSlotsScreen> createState() => _SaveSlotsScreenState();
}

class _SaveSlotsScreenState extends State<SaveSlotsScreen> {
  late Future<List<SaveSlot>> _slots = widget.setup.storage.listSlots();

  /// For the thumbnails. Null if the story can't be loaded, then the thumbnails show the mode only.
  late final Future<ProfileData?> _profiles =
      widget.setup.loader.initialLoad().then<ProfileData?>((package) => package.profiles).catchError((_) => null);

  bool get _saving => widget.onSave != null;

  String _describe(SaveSlot slot, StoryLanguage language) {
    final time = slot.updatedAt.toLocal();
    final stamp = "${time.year}-${_two(time.month)}-${_two(time.day)} ${_two(time.hour)}:${_two(time.minute)}";
    final label = [slot.chapter, slot.title].whereType<LocalizedText>().map(language.text).join(" · ");
    return "$label\n$stamp";
  }

  String _two(int value) => value.toString().padLeft(2, "0");

  String _name(int id, CeritaStrings strings) => switch (id) {
        SaveSlot.autoSlotId => strings.autosave,
        SaveSlot.quickSlotId => strings.quickSave,
        _ => strings.slot(id),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = StoryLanguage.of(context);
    final strings = language.strings;
    return Scaffold(
      appBar: AppBar(title: Text(_saving ? strings.saveGame : strings.loadGame)),
      body: FutureBuilder(
        future: Future.wait([_slots, _profiles]),
        builder: (context, snapshot) {
          final data = snapshot.data;
          final slots = {for (final slot in data?[0] as List<SaveSlot>? ?? const <SaveSlot>[]) slot.slotId: slot};
          final profiles = data?[1] as ProfileData?;
          final ids = [if (!_saving) ...[SaveSlot.autoSlotId, SaveSlot.quickSlotId], ...SaveSlotsScreen.manualSlots];
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final id in ids)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _saving || slots[id] != null
                        ? () async {
                            if (_saving) {
                              await widget.onSave!(id);
                              setState(() => _slots = widget.setup.storage.listSlots());
                            } else {
                              widget.onLoad?.call(slots[id]!);
                            }
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          SaveThumbnail(slot: slots[id], setup: widget.setup, profiles: profiles),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_name(id, strings), style: theme.textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                  slots[id] == null ? strings.emptySlot : _describe(slots[id]!, language),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

/// A save slot's stage in miniature: background and characters as they were saved.
/// Chat and call saves, and saves without a stage, show the mode instead.
class SaveThumbnail extends StatelessWidget {
  static const size = Size(64, 96);

  final SaveSlot? slot;
  final StorySetup setup;
  final ProfileData? profiles;

  const SaveThumbnail({super.key, required this.slot, required this.setup, this.profiles});

  @override
  Widget build(BuildContext context) {
    final slot = this.slot;
    final stage = slot?.stage;
    final mode = slot?.scene?.mode ?? SceneMode.vn;
    final scheme = Theme.of(context).colorScheme;

    final Widget child;
    if (slot == null || stage == null || mode != SceneMode.vn) {
      child = ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(
          switch (slot) {
            null => Icons.bookmark_outline,
            _ when mode == SceneMode.chat => Icons.chat_bubble_outline,
            _ when mode == SceneMode.call => Icons.call_outlined,
            _ => Icons.auto_stories_outlined,
          },
          color: scheme.outline,
        ),
      );
    } else {
      final config = setup.config;
      child = IgnorePointer(
        child: Poi(
          background: stage.background == null ? null : config.bg(stage.background!),
          actors: [
            for (final MapEntry(key: position, value: info) in stage.sprites.entries)
              if (profiles?.byId(info.id) case final profile?)
                if (profile.getSprite(info) case final sprite?)
                  PoiActor.of(profile, sprite: config.sprite(sprite), position: position),
          ],
          cast: profiles == null ? null : PoiCast.ofProfiles(profiles!.profiles),
          speakerId: stage.speakerId,
          zoom: stage.zoom,
          zoomFocus: stage.zoomFocus,
          instant: true,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.fromSize(size: size, child: child),
    );
  }
}
