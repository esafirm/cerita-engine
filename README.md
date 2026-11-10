# Cerita Engine

Flutter Simple Story Engine: a JSON-driven engine for visual novels, chat simulations, and hybrids of both.
See [`specs/`](specs/README.md) for the full specification.

## Demo

`cd example && flutter run` starts **Wrong Number**, a short demo story that uses every engine capability:

| Capability | Where |
| :--- | :--- |
| VN stage (backgrounds, 3 sprite slots, typewriter, CG) | Prologue, Day 2, VN endings |
| Messenger (typing, system pills, photo / voice note / video) | Day 1, chat endings |
| Call mode | Day 1 → "Let me call you" |
| `TEXT` `NARRATION` `MEDIA` `CHOICE` `INPUT` `BRANCH` `WAIT` `ENDING` | All chapters |
| Conditions, effects, `{{VAR}}` interpolation | Choices, Day 2 ending router |
| Autosave, save slots, gallery, endings, chapter checkpoints | Title screen and in-game menu |

The title screen's **Features** page lists each feature and where to see it.

## Layout

A [pub workspace](https://dart.dev/tools/pub/workspaces) with three packages and the demo app:

```text
packages/
├── cerita_core/       # Pure Dart: story model, engine, conditions, state & persistence interfaces
├── cerita_flutter/    # Asset loader, SharedPreferences storage, StoryScreen and the default views
│                      # (VN stage, chat, call, meta screens), restyled through StorySkin
└── cerita_ui/         # Anime VN skin: transitions, dialogue box, choices, HUD, chapter card,
                       # dark theme and an animated title screen
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
