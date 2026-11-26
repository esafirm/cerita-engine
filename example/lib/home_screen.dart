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

  /// Shown on the title screen when the story ships a credits.json.
  Credits? _credits;

  @override
  void initState() {
    super.initState();
    setup.loader.loadCredits().then((credits) {
      if (mounted) setState(() => _credits = credits);
    }, onError: (Object _) {});
  }

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
    final strings = _demoStringsOf(StoryLanguage.of(context));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.resetTitle),
        content: Text(strings.resetBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(strings.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(strings.reset)),
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
    final language = StoryLanguage.of(context);
    final strings = language.strings;
    final demoStrings = _demoStringsOf(language);
    return FutureBuilder(
      future: _autosave,
      builder: (context, snapshot) {
        final save = snapshot.data;
        return CeritaTitleScreen(
          title: "Wrong Number",
          subtitle: "A Cerita Engine demo",
          art: Poi(
            background: config.bg("bg_sitting_room_night.png"),
            actors: [
              PoiActor(id: "nora", sprite: config.sprite("nora_smile.png"), position: SpritePosition.left),
              PoiActor(id: "miki", sprite: config.sprite("miki_open.png"), position: SpritePosition.center),
              PoiActor(id: "luna", sprite: config.sprite("luna_smile.png"), position: SpritePosition.right),
            ],
          ),
          primary: [
            if (save != null)
              TitleMenuEntry(
                label: "${strings.continueGame} · ${language.maybe(save.chapter) ?? ""}",
                icon: Icons.play_arrow_rounded,
                onTap: () => _play(save: save),
              ),
            TitleMenuEntry(label: strings.newGame, icon: Icons.auto_stories, onTap: () => _play()),
          ],
          secondary: [
            TitleMenuEntry(
              label: strings.load,
              icon: Icons.folder_open,
              onTap: () => _push(
                SaveSlotsScreen(
                  setup: setup,
                  onLoad: (save) => _replaceWithStory(save: save),
                ),
              ),
            ),
            TitleMenuEntry(
              label: strings.chapters,
              icon: Icons.timeline,
              onTap: () => _push(
                ChaptersScreen(
                  setup: setup,
                  onSelect: (checkpoint) => _replaceWithStory(checkpoint: checkpoint),
                  // On top of the chapter list, so the replay comes back to it.
                  onReplay: (checkpoint) => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => StoryScreen(setup: setup, checkpoint: checkpoint, replay: true),
                  )),
                ),
              ),
            ),
            TitleMenuEntry(
              label: strings.gallery,
              icon: Icons.photo_library_outlined,
              onTap: () => _push(GalleryScreen(setup: setup)),
            ),
            TitleMenuEntry(
              label: strings.endings,
              icon: Icons.emoji_events_outlined,
              onTap: () => _push(EndingsScreen(setup: setup)),
            ),
            TitleMenuEntry(
              label: strings.music,
              icon: Icons.library_music_outlined,
              onTap: () => _push(MusicRoomScreen(setup: setup)),
            ),
            TitleMenuEntry(
              label: strings.settings,
              icon: Icons.tune,
              onTap: () => _push(SettingsScreen(settings: setup.settings, loader: setup.loader)),
            ),
            // A single-language story like Wrong Number has nothing to switch to.
            if (language.available.length > 1)
              TitleMenuEntry(label: strings.language, icon: Icons.translate, onTap: () => LanguagePicker.show(context)),
            if (_credits != null)
              TitleMenuEntry(
                label: strings.credits,
                icon: Icons.groups_outlined,
                onTap: () => _push(CreditsScreen(setup: setup)),
              ),
            TitleMenuEntry(
              label: demoStrings.features,
              icon: Icons.checklist,
              onTap: () => _push(const CapabilitiesScreen()),
            ),
            TitleMenuEntry(label: demoStrings.reset, icon: Icons.restart_alt, onTap: _resetProgress),
          ],
        );
      },
    );
  }
}

/// The demo's own title screen strings, by locale. Engine strings come from [CeritaStrings]. The Features screen
/// itself stays in English: it lists engine capabilities for developers.
typedef _DemoStrings = ({String features, String reset, String resetTitle, String resetBody, String cancel});

const _demoStrings = <String, _DemoStrings>{
  "en": (
    features: "Features",
    reset: "Reset",
    resetTitle: "Reset progress?",
    resetBody: "Deletes every save slot, gallery unlock, ending, checkpoint and remembered fact.",
    cancel: "Cancel",
  ),
  "id": (
    features: "Fitur",
    reset: "Atur ulang",
    resetTitle: "Atur ulang progres?",
    resetBody: "Menghapus semua slot simpanan, gambar galeri yang terbuka, ending, checkpoint dan fakta yang diingat.",
    cancel: "Batal",
  ),
};

/// [_demoStrings] in [language]'s active locale, else English.
_DemoStrings _demoStringsOf(StoryLanguage language) =>
    _demoStrings[language.locale ?? language.locales.source] ?? _demoStrings["en"]!;
