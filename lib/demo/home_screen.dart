import 'package:flutter/material.dart';
import 'package:fsse/fsse.dart';
import 'package:fsse/src/presentation/meta/chapters_screen.dart';
import 'package:fsse/src/presentation/meta/endings_screen.dart';
import 'package:fsse/src/presentation/meta/gallery_screen.dart';
import 'package:fsse/src/presentation/meta/save_slots_screen.dart';
import 'package:fsse/src/presentation/story_screen.dart';
import 'package:fsse/src/presentation/story_setup.dart';
import 'package:fsse/src/presentation/vn/poi.dart';

import 'capabilities_screen.dart';

/// Title screen of the demo story "Wrong Number".
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

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() => _autosave = _loadAutosave());
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
    if (mounted) setState(() => _autosave = _loadAutosave());
  }

  @override
  Widget build(BuildContext context) {
    final config = setup.config;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Poi(
            background: config.bg("bg_sitting_room_night.png"),
            sprites: {
              SpritePosition.left: config.sprite("nora_smile.png"),
              SpritePosition.center: config.sprite("miki_open.png"),
              SpritePosition.right: config.sprite("luna_smile.png"),
            },
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xAA000000), Color(0x00000000), Color(0xEE000000)],
                stops: [0, 0.35, 0.85],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Wrong Number",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "A Cerita Engine demo",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const Spacer(),
                  FutureBuilder(
                    future: _autosave,
                    builder: (context, snapshot) {
                      final save = snapshot.data;
                      if (save == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FilledButton.icon(
                          onPressed: () => _play(save: save),
                          icon: const Icon(Icons.play_arrow),
                          label: Text("Continue · ${save.chapter ?? ""}"),
                        ),
                      );
                    },
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _play(),
                    icon: const Icon(Icons.auto_stories),
                    label: const Text("New game"),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MenuChip(
                        icon: Icons.folder_open,
                        label: "Load",
                        onTap: () => _push(SaveSlotsScreen(setup: setup, onLoad: (save) => _replaceWithStory(save: save))),
                      ),
                      _MenuChip(
                        icon: Icons.timeline,
                        label: "Chapters",
                        onTap: () => _push(ChaptersScreen(
                          setup: setup,
                          onSelect: (checkpoint) => _replaceWithStory(checkpoint: checkpoint),
                        )),
                      ),
                      _MenuChip(
                        icon: Icons.photo_library_outlined,
                        label: "Gallery",
                        onTap: () => _push(GalleryScreen(setup: setup)),
                      ),
                      _MenuChip(
                        icon: Icons.emoji_events_outlined,
                        label: "Endings",
                        onTap: () => _push(EndingsScreen(setup: setup)),
                      ),
                      _MenuChip(
                        icon: Icons.checklist,
                        label: "Capabilities",
                        onTap: () => _push(const CapabilitiesScreen()),
                      ),
                      _MenuChip(icon: Icons.restart_alt, label: "Reset", onTap: _resetProgress),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(avatar: Icon(icon, size: 18), label: Text(label), onPressed: onTap);
  }
}
