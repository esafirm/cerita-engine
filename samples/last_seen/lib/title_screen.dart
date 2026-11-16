import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:cerita_ui/cerita_ui.dart';
import 'package:flutter/material.dart';

/// The Last Seen title screen, built on [CeritaTitleScreen].
class TitleScreen extends StatefulWidget {
  final StorySetup setup;

  const TitleScreen({super.key, required this.setup});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  late Future<SaveSlot?> _autosave = _loadAutosave();

  /// Null hides the Credits entry until the story ships a credits.json.
  Credits? _credits;

  StorySetup get setup => widget.setup;

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

  @override
  Widget build(BuildContext context) {
    final config = setup.config;
    final language = StoryLanguage.of(context);
    final strings = language.strings;
    return FutureBuilder(
      future: _autosave,
      builder: (context, snapshot) {
        final save = snapshot.data;
        return CeritaTitleScreen(
          title: "Last Seen",
          subtitle: language.locale == "en" ? "A North Jakarta mystery" : "Terakhir dilihat",
          art: Poi(
            background: config.bg("bg_seawall_night.webp"),
            actors: [
              PoiActor(id: "raka", sprite: config.sprite("raka_neutral.webp"), position: SpritePosition.left),
              PoiActor(id: "sekar", sprite: config.sprite("sekar_smile.webp"), position: SpritePosition.right),
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
              onTap: () => _push(SaveSlotsScreen(setup: setup, onLoad: (save) => _replaceWithStory(save: save))),
            ),
            TitleMenuEntry(
              label: strings.chapters,
              icon: Icons.timeline,
              onTap: () => _push(
                ChaptersScreen(
                  setup: setup,
                  onSelect: (checkpoint) => _replaceWithStory(checkpoint: checkpoint),
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
              label: strings.settings,
              icon: Icons.tune,
              onTap: () => _push(SettingsScreen(settings: setup.settings, loader: setup.loader)),
            ),
            TitleMenuEntry(label: strings.language, icon: Icons.translate, onTap: () => LanguagePicker.show(context)),
            if (_credits != null)
              TitleMenuEntry(
                label: strings.credits,
                icon: Icons.groups_outlined,
                onTap: () => _push(CreditsScreen(setup: setup)),
              ),
          ],
        );
      },
    );
  }
}
