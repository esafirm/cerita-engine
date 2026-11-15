<p align="center">
  <img src="docs/images/logo.png" alt="Cerita Engine logo" width="160">
</p>

# Cerita Engine

Flutter Simple Story Engine: a JSON-driven engine for visual novels, chat simulations, and hybrids of both.
See [`specs/`](specs/README.md) for the full specification.

## Demo

`cd example && flutter run` starts **Wrong Number**, a short demo story that uses every engine capability:

| Capability | Where |
| :--- | :--- |
| VN stage (backgrounds, 5 sprite slots, typewriter, CG) | Prologue, Day 2, VN endings |
| `STAGE` direction (show / hide / move, transitions, shake, flash, zoom, weather, music) | Prologue, Day 2, true ending |
| Messenger (typing, system pills, photo / voice note / video) | Day 1, chat endings |
| Call mode | Day 1 → "Let me call you" |
| `TEXT` `NARRATION` `MEDIA` `CHOICE` `INPUT` `BRANCH` `WAIT` `ENDING` | All chapters |
| Labels, `JUMP`, `CALL` / `RETURN`, `SET`, `once` choices | Prologue question hub, shared phone buzz |
| Conditions, effects, expressions (`random()`, arithmetic), `{{VAR}}` interpolation | Choices, Day 2 greeting and ending router |
| `persistent.*` variables | Prologue run counter |
| Autosave, save slots with thumbnails, gallery, endings, chapter checkpoints | Title screen and in-game menu |
| Rollback (also from the backlog, kept in saves, stable `random()`), quick save / load, hide UI | VN quick controls |
| Settings (text speed, auto delay, skip unread, volumes), music room, chapter replay | Title screen and in-game menu |
| Text tags (`{b}` `{i}` `{color}` `{shake}` `{wave}` `{speed}` `{w}` `{nw}`) in lines and choices, NVL page | Prologue opening and menu, Day 2, secret ending |
| Music fades, ambience loop, overlapping sounds, per-character voice volume, voice replay | Prologue → "Nah", settings, backlog |
| Developer panel (edit variables, jump to any label, story check, reload on hot reload) | In-game menu → Developer, debug builds |

The title screen's **Features** page lists each feature and where to see it.

## Layout

A [pub workspace](https://dart.dev/tools/pub/workspaces) with four packages and the demo app:

```text
packages/
├── cerita_core/       # Pure Dart: story model, engine, conditions, state & persistence interfaces
├── cerita_flutter/    # Asset loader, SharedPreferences storage, StoryScreen and the default views
│                      # (VN stage, chat, call, meta screens), restyled through StorySkin
├── cerita_ui/         # Anime VN skin: transitions, dialogue box, choices, HUD, chapter card,
│                      # dark theme and an animated title screen
└── cerita_tools/      # Pure Dart CLI: compiles .cerita scripts to story JSON, lints them,
                       # estimates playtime and exports voice and asset lists
example/               # Demo app, story in example/assets/story/ (see specs/data-schema.md)
```

## Skinning

`cerita_flutter` draws the story through a `StorySkin`. The defaults are plain Material. Provide another
skin above the story screen to change the dialogue box, choice buttons, VN HUD, sprite/background/scene
transitions and the chapter title card:

```dart
MaterialApp(
  theme: CeritaTheme.dark(),
  builder: (context, child) => StorySkinScope(skin: const AnimeVnSkin(), child: child!),
  home: StoryScreen(setup: StorySetup.assets()),
);
```

Subclass `StorySkin` (or `AnimeVnSkin`) and override only the hooks you need.

## Languages

A story can hold every language side by side: any player-visible text is a string or `{"id": "...", "en": "..."}`, and
`index.json` declares `source_locale` and `locales`. Provide a `StoryLanguage` to switch story text, voice clips
and the engine screens (Indonesian and English built in):

```dart
final language = StoryLanguage();
await language.load(setup); // saved pick, else device language, else the source language
// MaterialApp(builder: (context, child) => StoryLanguageScope(language: language, child: child!), ...)
```

See [data schema section 5](specs/data-schema.md#5-localized-text) and
[presentation modes section 5](specs/presentation-modes.md#5-language).

## Using the engine

```dart
final engine = RealFsseEngine(
  AssetEngineLoader(const LoaderConfig()),
  storage: SharedPrefsStoryStorage(),
);

var item = await engine.next();
if (item is ChoiceItemType) {
  item = await engine.next(prevResult: ItemResult.choice(item.variable, item.availableChoices.first));
}
await engine.saveTo(1);
```

## Development

The root `Makefile` wraps the common tasks. Run `make` to list them.

```sh
make check                          # analyze and run every test suite, like CI
make run                            # flutter run the demo
make install DEVICE=emulator-5554   # profile build, install (keeping saves) and launch
```

`example/test/story_test.dart` plays the bundled story headlessly to all four endings.

Known work that isn't scheduled yet is in [`BACKLOG.md`](BACKLOG.md). Judgment calls, with their reasons and when to revisit them, are in [`docs/decisions.md`](docs/decisions.md): add an entry when you make one.

Keep tests focused on behaviour a player or writer would notice: story flow, saves, rollback, what the screens show. Don't add low-value tests, like ones for trivial helpers, getters or formatting, or ones that repeat what another test already covers.

## Writing a story

Stories can be written as readable `.cerita` scripts instead of JSON (see
[`specs/authoring-toolkit.md`](specs/authoring-toolkit.md)):

```text
@conversation day1 chapter="Day 1" checkpoint
@scene CHAT channel=thread_miki day=1 time=23:45

miki:frown typing=2.6s
  en: please answer. it's about Luna.

choice FIRST_REPLY by=miki timeout=10s
  en: How do you reply?
? Who is Luna? Tell me everything.
  +miki_trust 5
? Wrong number. Who is this? [default]
  -miki_trust 5
```

```sh
dart run cerita_tools compile <story> <out>   # scripts to engine JSON (--check verifies committed files)
dart run cerita_tools lint <story> --release  # every broken link, unknown name, missing asset and translation
dart run cerita_tools stats <story>           # words and minutes per chapter, route and ending
dart run cerita_tools tts-manifest <story>    # voiced lines for the voice pipeline
dart run cerita_tools assets <story>          # files the story uses that don't exist yet
```

Wrong Number is also written as a script in `packages/cerita_tools/test/fixtures/wrong_number/`. Its tests check
that it compiles to the hand-written JSON in `example/assets/story/` and plays to the same four endings.
