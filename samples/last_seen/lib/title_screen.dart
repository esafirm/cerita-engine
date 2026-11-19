import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';

import 'store/full_game.dart';
import 'store/paywall.dart';
import 'ui/retro.dart';

/// The Last Seen title screen: key art and logo with a blinking "tap to start", then a text menu with a cursor.
class TitleScreen extends StatefulWidget {
  final StorySetup setup;
  final FullGame fullGame;

  const TitleScreen({super.key, required this.setup, required this.fullGame});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  static const _music = "bgm_low_tide.mp3";

  late Future<SaveSlot?> _autosave = _loadAutosave();
  final AudioHelper _audio = AudioHelper();

  /// Null hides the Credits entry until the story ships a credits.json.
  Credits? _credits;

  bool _started = false;

  /// The cast, so the key art stands at the heights the story uses. Null until loaded.
  ProfileData? _cast;

  /// Held down: the logo and menu step aside to show the key art.
  bool _peek = false;
  bool _extras = false;
  int _cursor = 0;

  StorySetup get setup => widget.setup;

  @override
  void initState() {
    super.initState();
    _audio.addObserver();
    _playMusic();
    widget.fullGame.addListener(_fullGameChanged);
    setup.loader.loadCredits().then((credits) {
      if (mounted) setState(() => _credits = credits);
    }, onError: (Object _) {});
    setup.loader.initialLoad().then((package) {
      if (mounted) setState(() => _cast = package.profiles);
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    widget.fullGame.removeListener(_fullGameChanged);
    _audio.removeObserver();
    super.dispose();
  }

  // The Unlock entry comes and goes with the purchase.
  void _fullGameChanged() {
    if (mounted) setState(() {});
  }

  void _openPaywall() {
    void close() => Navigator.of(context).pop();
    _push(Scaffold(body: Paywall(fullGame: widget.fullGame, onUnlocked: close, onLeave: close)));
  }

  void _playMusic() {
    final settings = setup.settings.value;
    _audio.setVolumes(music: settings.musicVolume, sound: settings.soundVolume, voice: settings.voiceVolume);
    _audio.playBgm(setup.config.music(_music));
  }

  Future<SaveSlot?> _loadAutosave() => setup.storage.loadSlot(SaveSlot.autoSlotId);

  // A block body: setState throws if its callback returns a Future.
  void _reloadAutosave() {
    _autosave = _loadAutosave();
  }

  Future<void> _push(Widget screen) async {
    // The story plays its own music.
    if (screen is StoryScreen) _audio.playBgm(null, fadeMs: 400);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    _playMusic();
    setState(_reloadAutosave);
  }

  Future<void> _play({SaveSlot? save, Checkpoint? checkpoint}) =>
      _push(StoryScreen(setup: setup, save: save, checkpoint: checkpoint));

  void _replaceWithStory({SaveSlot? save, Checkpoint? checkpoint}) {
    Navigator.of(context).pop();
    _play(save: save, checkpoint: checkpoint);
  }

  void _start() {
    UiSounds.instance?.start();
    setState(() => _started = true);
  }

  void _setPeek(bool peek) {
    if (_peek != peek) setState(() => _peek = peek);
  }

  void _showExtras(bool extras) {
    extras ? UiSounds.instance?.confirm() : UiSounds.instance?.cancel();
    setState(() {
      _extras = extras;
      _cursor = 0;
    });
  }

  List<(String, VoidCallback)> _entries(SaveSlot? save) {
    final language = StoryLanguage.of(context);
    final strings = language.strings;
    final en = language.locale == "en";
    if (_extras) {
      return [
        (strings.gallery, () => _push(GalleryScreen(setup: setup))),
        (strings.endings, () => _push(EndingsScreen(setup: setup))),
        if (_credits != null) (strings.credits, () => _push(CreditsScreen(setup: setup))),
        (strings.back, () => _showExtras(false)),
      ];
    }
    return [
      if (save != null) ("${strings.continueGame} · ${language.maybe(save.chapter) ?? ""}", () => _play(save: save)),
      (strings.newGame, () => _play()),
      (
        strings.load,
        () => _push(
          SaveSlotsScreen(
            setup: setup,
            onLoad: (save) => _replaceWithStory(save: save),
          ),
        ),
      ),
      (
        strings.chapters,
        () => _push(
          ChaptersScreen(
            setup: setup,
            onSelect: (checkpoint) => _replaceWithStory(checkpoint: checkpoint),
            onReplay: (checkpoint) => _push(StoryScreen(setup: setup, checkpoint: checkpoint, replay: true)),
          ),
        ),
      ),
      if (!widget.fullGame.unlocked) (en ? "Unlock full game" : "Buka game lengkap", _openPaywall),
      (en ? "Extras" : "Ekstra", () => _showExtras(true)),
      (strings.settings, () => _push(SettingsScreen(settings: setup.settings, loader: setup.loader))),
      (strings.language, () => LanguagePicker.show(context)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final config = setup.config;
    final language = StoryLanguage.of(context);
    final en = language.locale == "en";
    return PopScope(
      canPop: !_started,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _extras ? _showExtras(false) : setState(() => _started = false);
      },
      child: Scaffold(
        // Holding anywhere but the menu shows the art without the logo and menu, until the finger lifts.
        body: HoldToPeek(
          onPeek: _setPeek,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Poi(
                background: config.bg("bg_seawall_night.webp"),
                // They step in once the cast is read, already at their heights.
                actors: [
                  if (_cast case final cast?)
                    for (final (id, sprite, position) in const [
                      ("raka", "raka_neutral.webp", SpritePosition.left),
                      ("sekar", "sekar_smile.webp", SpritePosition.right),
                    ])
                      if (cast.byId(id) case final profile?)
                        PoiActor.of(profile, sprite: config.sprite(sprite), position: position),
                ],
                cast: _cast == null ? null : PoiCast.ofProfiles(_cast!.profiles),
              ),
              IgnorePointer(
                ignoring: _peek,
                child: AnimatedOpacity(
                  opacity: _peek ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 36, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Seven quick taps on the logo open the admin tools: unlock everything, developer panel.
                          AdminGate(
                            setup: setup,
                            child: _Logo(subtitle: en ? "A North Jakarta mystery" : "Misteri Jakarta Utara"),
                          ),
                          const Spacer(),
                          if (_started)
                            FutureBuilder(
                              future: _autosave,
                              builder: (context, snapshot) => _Menu(
                                entries: _entries(snapshot.data),
                                cursor: _cursor,
                                onSelect: (index, action) {
                                  if (index != _cursor) setState(() => _cursor = index);
                                  UiSounds.instance?.confirm();
                                  action();
                                },
                              ),
                            )
                          else
                            Blink(
                              child: Text(
                                en ? "- TAP TO START -" : "- SENTUH UNTUK MULAI -",
                                textAlign: TextAlign.center,
                                style: Retro.text.copyWith(
                                  fontSize: 18,
                                  letterSpacing: 3,
                                  shadows: const [Shadow(color: Retro.night, offset: Offset(2, 2))],
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),
                          Text(
                            "© 2026 CERITA ENGINE",
                            textAlign: TextAlign.center,
                            style: Retro.text.copyWith(
                              color: Retro.dim,
                              fontSize: 11,
                              letterSpacing: 2,
                              shadows: const [Shadow(color: Retro.night, offset: Offset(1, 1))],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Before the menu is up, a tap anywhere starts.
              if (!_started) GestureDetector(behavior: HitTestBehavior.opaque, onTap: _start),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final String subtitle;

  const _Logo({required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          "LAST SEEN",
          textAlign: TextAlign.center,
          style: Retro.text.copyWith(
            fontSize: 50,
            height: 1.1,
            letterSpacing: 4,
            // Stacked hard shadows, like a logo printed in two inks.
            shadows: const [
              Shadow(color: Retro.accent, offset: Offset(3, 3)),
              Shadow(color: Retro.night, offset: Offset(6, 6)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle.toUpperCase(),
          textAlign: TextAlign.center,
          style: Retro.text.copyWith(
            fontSize: 13,
            letterSpacing: 3,
            shadows: const [Shadow(color: Retro.night, offset: Offset(2, 2))],
          ),
        ),
      ],
    );
  }
}

class _Menu extends StatelessWidget {
  final List<(String, VoidCallback)> entries;
  final int cursor;
  final void Function(int index, VoidCallback action) onSelect;

  const _Menu({required this.entries, required this.cursor, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: RetroWindow(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, (label, action)) in entries.indexed)
                // The mouse region marks it as a button, so holding it doesn't hide the menu (see HoldToPeek).
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(index, action),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 26,
                            child: index == cursor
                                ? Blink(
                                    period: const Duration(milliseconds: 800),
                                    child: const Align(alignment: Alignment.centerLeft, child: RetroCursor(size: 14)),
                                  )
                                : null,
                          ),
                          Flexible(
                            child: Text(
                              label.toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                              style: Retro.text.copyWith(
                                fontSize: 17,
                                height: 1.2,
                                letterSpacing: 2.4,
                                color: index == cursor ? Retro.frame : Retro.frame.withAlpha(200),
                              ),
                            ),
                          ),
                        ],
                      ),
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
