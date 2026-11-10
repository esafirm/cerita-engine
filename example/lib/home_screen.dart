import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:cerita_ui/cerita_ui.dart';
import 'package:flutter/material.dart';

import 'capabilities_screen.dart';

/// Title screen of the demo story "Wrong Number", built on [CeritaTitleScreen].
class HomeScreen extends StatefulWidget {
  final StorySetup setup;

  const HomeScreen({super.key, required this.setup});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<SaveSlot?> _autosave = _loadAutosave();

  StorySetup get setup => widget.setup;

  Future<SaveSlot?> _loadAutosave() => setup.storage.loadSlot(SaveSlot.autoSlotId);

  // A block body: setState throws if its callback returns a Future.
  void _reloadAutosave() {
    _autosave = _loadAutosave();
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(_reloadAutosave);
  }

  Future<void> _play({SaveSlot? save, Checkpoint? checkpoint}) =>
      _push(StoryScreen(setup: setup, save: save, checkpoint: checkpoint));

  void _replaceWithStory({SaveSlot? save, Checkpoint? checkpoint}) {
    Navigator.of(context).pop();
    _play(save: save, checkpoint: checkpoint);
  }

  Future<void> _resetProgress() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset progress?"),
        content: const Text("Deletes every save slot, gallery unlock, ending and checkpoint."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Reset")),
        ],
      ),
    );
    if (confirmed != true) return;
    await setup.storage.clear();
    if (mounted) setState(_reloadAutosave);
  }

  @override
  Widget build(BuildContext context) {
    final config = setup.config;
    return FutureBuilder(
      future: _autosave,
      builder: (context, snapshot) {
        final save = snapshot.data;
        return CeritaTitleScreen(
          title: "Wrong Number",
          subtitle: "A Cerita Engine demo",
          art: Poi(
            background: config.bg("bg_sitting_room_night.png"),
            sprites: {
              SpritePosition.left: config.sprite("nora_smile.png"),
              SpritePosition.center: config.sprite("miki_open.png"),
              SpritePosition.right: config.sprite("luna_smile.png"),
            },
          ),
          primary: [
            if (save != null)
              TitleMenuEntry(
                label: "Continue · ${save.chapter ?? ""}",
                icon: Icons.play_arrow_rounded,
                onTap: () => _play(save: save),
              ),
            TitleMenuEntry(label: "New game", icon: Icons.auto_stories, onTap: () => _play()),
          ],
          secondary: [
            TitleMenuEntry(
              label: "Load",
              icon: Icons.folder_open,
              onTap: () => _push(
                SaveSlotsScreen(
                  setup: setup,
                  onLoad: (save) => _replaceWithStory(save: save),
                ),
              ),
            ),
            TitleMenuEntry(
              label: "Chapters",
              icon: Icons.timeline,
              onTap: () => _push(
                ChaptersScreen(
                  setup: setup,
                  onSelect: (checkpoint) => _replaceWithStory(checkpoint: checkpoint),
                ),
              ),
            ),
            TitleMenuEntry(
              label: "Gallery",
              icon: Icons.photo_library_outlined,
              onTap: () => _push(GalleryScreen(setup: setup)),
            ),
            TitleMenuEntry(
              label: "Endings",
              icon: Icons.emoji_events_outlined,
              onTap: () => _push(EndingsScreen(setup: setup)),
            ),
            TitleMenuEntry(label: "Features", icon: Icons.checklist, onTap: () => _push(const CapabilitiesScreen())),
            TitleMenuEntry(label: "Reset", icon: Icons.restart_alt, onTap: _resetProgress),
          ],
        );
      },
    );
  }
}
