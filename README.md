# Cerita Engine (`fsse`)

Flutter Simple Story Engine: a JSON-driven engine for visual novels, chat simulations, and hybrids of both.
See [`specs/`](specs/README.md) for the full specification.

## Demo

`flutter run` starts **Wrong Number**, a short demo story that uses every engine capability:

| Capability | Where |
| :--- | :--- |
| VN stage (backgrounds, 3 sprite slots, typewriter, CG) | Prologue, Day 2, VN endings |
| Messenger (typing, system pills, photo / voice note / video) | Day 1, chat endings |
| Call mode | Day 1 → "Let me call you" |
| `TEXT` `NARRATION` `MEDIA` `CHOICE` `INPUT` `BRANCH` `WAIT` `ENDING` | All chapters |
| Conditions, effects, `{{VAR}}` interpolation | Choices, Day 2 ending router |
| Autosave, save slots, gallery, endings, chapter checkpoints | Title screen and in-game menu |

The title screen's **Capabilities** page lists each feature and where to see it.

## Layout

```text
lib/
├── fsse.dart                  # Engine public API
├── src/engine/                # Headless core: loader, items, evaluator, state & persistence
├── src/presentation/          # VN stage, chat, call, meta screens, StoryController
└── demo/                      # Demo app (title screen, capabilities)
assets/story/                  # Demo story (see specs/data-schema.md)
```

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

## Tests

```sh
flutter test
```

`test/story_test.dart` plays the bundled story headlessly to all four endings.
