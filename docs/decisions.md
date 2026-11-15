# Decisions

Judgment calls that the specs and code don't explain on their own. Each one says what was decided, why, and
when to revisit it. Add an entry when you make a call that someone could reasonably have made the other way.
The specs in [`specs/`](../specs/README.md) stay the source of truth for behaviour; this file keeps the reasons.

## Saves keep the full rollback log

*2026-11-15. Engine §5.2, §7.*

Saves carry the rollback frames, so rollback reaches back past a load. Only rollback targets and the frame the
save was made in are written; stage directions and waits in between are dropped, since rollback never stops on
them. Up to 100 frames are kept, the same as in memory.

- **Why:** a capped or manual-save-only log would make rollback depth depend on how the player got there.
- **Cost:** about 650 bytes per frame in the demo, so a full log adds about 65 KB to every autosave, which is
  written after each line. The demo's largest autosave went from 11 KB to 28 KB.
- **Revisit if** autosaves get slow on a device or on the web. Options, cheapest first: keep fewer frames in
  saves than in memory, write the log only for manual and quick saves, or store frames as diffs.

## `random()` replays after a rollback, whatever the player picks next

*2026-11-15. Engine §7.*

Every `random()` roll is recorded with its range. Moving forward after a rollback replays the rolls in order,
even if the player picks another choice. A call with another range drops the recorded rest and rolls fresh.
The rolls are saved with the rollback log.

- **Why:** rollback can't be used to reroll a result, and replaying by position needs no knowledge of which
  item rolled what. Dropping on a range mismatch keeps a replayed value from falling outside its range.
- **Revisit if** a story wants a new roll after a different choice. Then drop the recorded rolls when a
  CHOICE or INPUT is answered differently from the frame it was rolled back to.

## Variable values never carry text tags

*2026-11-15. Data schema §6.*

`{{VAR}}` values inserted into `text` fields (lines, prompts, choice options) have their `{` escaped, so tags
in them show as written. This applies to every variable, not only those set by `INPUT`.

- **Why:** the backlog asked for INPUT values, but limiting it to them would mean tracking which variables
  came from INPUT, in the save too. Values are data and tags belong in the story text, so escaping all of
  them is simpler and closes the same hole.
- **Cost:** an author can't keep styled text in a variable (`SET title = "{b}Boss{/b}"`) and have it render.
- **Revisit if** a story needs that. Add an explicit raw form, such as `{{!VAR}}`, rather than going back to
  unescaped values.

## `{{` is the escape for a literal `{`

*2026-11-15. Data schema §6.*

The markup parser reads `{{` as a `{` that doesn't start a tag. Interpolation runs first and only matches
`{{NAME}}`, so the two don't clash. A line that used `{{` on its own now shows a single `{`. The linter doesn't
report an escaped `{{b}` as an unknown tag.

- **Why:** the same escape as Ren'Py, and it needs no new syntax.

## HIDE pauses both auto and skip

*2026-11-15. Presentation modes §2.*

While the VN UI is hidden, neither auto nor skip advances. Both carry on once a tap brings the UI back.
WAIT items and stage directions still run, since they aren't player-driven.

- **Why:** hiding is for looking at the stage, and lines changing behind it defeat that.

## The codebase is not run through `dart format`

*2026-11-15.*

The code is formatted by hand to 120 columns, and `dart format --line-length 120` would rewrite most files.
Match the style around your change instead of formatting whole files.

- **Revisit if** we want a formatter in CI. Then format everything in one commit of its own.

## Remembered facts are their own set, not `persistent.*` variables

*2026-11-15. Engine §2 Cross-Playthrough Memory, §5.1. Backlog CE-03.*

`meta_set` adds a name to `remembered_facts` in the meta-state, read back as `meta.flag.<name>`. It doesn't
write `persistent.<name>`, even though persistent variables already survive new games.

- **Why:** the CE-03 contract is a write-once fact list. Keeping it apart means a fact can't be overwritten,
  decremented or clash with an author's persistent counter of the same name, and the linter can tell facts
  from variables. Reset progress clears both, since it wipes the whole meta-state.
- **Cost:** two cross-run mechanisms. The spec says when to use which.
- **Revisit if** authors keep mixing them up. Then `meta.flag.x` could become an alias of a persistent bool.

## A locked choice that reads memory is hidden, not shown locked

*2026-11-15. Engine §2 Cross-Playthrough Memory, data schema §4.4. Backlog CE-03.*

A choice whose `condition` reads `meta.*` and fails is left out of the menu. Choices gated only on run
variables keep the locked look.

- **Why:** the PRD wants first playthroughs to look exactly as they would without the feature, and wants a
  memory-gated choice to stay hidden until earned. A lock would spoil the reward on run one.
- **Cost:** it's implicit. A condition like `meta.ending.a || trust > 5` hides the choice when locked even
  though part of it is run state.
- **Revisit if** an author wants a visible "locked until you've seen more" teaser. A per-choice flag can
  override the rule then.

## The memory marker is a sparkle with no screen-reader label yet

*2026-11-15. Engine §2 Cross-Playthrough Memory. Backlog CE-03.*

`memory_marker: true` on a choice shows `StorySkin.memoryMarker`, by default an `Icons.auto_awesome` icon,
while the choice is available. Skins restyle it by overriding the hook or hide it by returning null.

- **Why:** an icon needs no text, so it doesn't touch the UI strings that CE-01 is localizing.
- **Revisit when** CE-01 lands: give the marker a localized semantics label, e.g. "Unlocked by a past run".
  Done in CE-01: `CeritaStrings.memoryMarker`.

## The player's language is our own notifier, not Flutter's `Localizations`

*2026-11-15. Presentation modes §5, CE-01.*

`StoryLanguage` (a `ChangeNotifier` provided by `StoryLanguageScope`) holds the active locale and the engine
strings. `MaterialApp.locale` and `LocalizationsDelegate` aren't used.

- **Why:** the language is a player setting that changes mid-game, not the app's locale. Feeding `id` to
  `MaterialApp.locale` needs `flutter_localizations` for Material's own widgets, a new dependency for strings
  the engine barely shows.
- **Cost:** Material's built-in text (tooltips on back buttons, date pickers) stays in the app's locale.
- **Revisit if** an integrating app needs Material's own strings to follow the story language.

## A missing locale key falls back, an empty string doesn't

*2026-11-15. Data schema §5.2.*

Fallback only happens when the active locale has no key in the text object. `{"id": "Halo", "en": ""}` shows an
empty line in English.

- **Why:** the shared contract defines the order by key presence. Treating `""` as missing would be a second
  rule the authoring toolkit (CE-02) has to mirror.
- **Revisit if** CE-02 emits empty strings for untranslated lines. Then either it omits the key or the engine
  treats `""` as missing.

## A localized choice without `value` stores its source-language text

*2026-11-15. Data schema §5.3.*

- **Why:** state and conditions must not depend on the language the player picked, so a save made in English
  plays the same in Indonesian. Plain-string options keep storing their text, so Wrong Number is unchanged.
- **Cost:** an author who wants the shown text in a variable has to interpolate it in each language.

## Engine screens fall back to English, not the story's source language

*2026-11-15. Presentation modes §5.2.*

`CeritaStrings` lookup is the active locale, else English. Without a picked locale (no `StoryLanguageScope`,
or before `load`) the engine screens are English and story text is in its source language.

- **Why:** a player whose language has no engine strings is more likely to read English than the story's
  source language. And apps that never set up a language keep the English screens they had before CE-01.
- **Cost:** an English-only story must declare `"source_locale": "en"`, since the contract's default source is
  `"id"`. Wrong Number now declares it.

## The language is a player setting, not a separate store

*2026-11-15. Engine §5.3, §9.4.*

The active language is `PlayerSettings.locale`, saved with the other player settings and kept by "reset
progress". `StoryLanguage` reads and writes it through `StorySetup.settings`, so the Settings screen and the
language picker never overwrite each other.

- **Why:** one settings store, and the Settings screen is where players look for it (PRD 10.3, CE-04).

## Indonesian HUD labels stay short

*2026-11-15. CE-01 risk "longer text overflows".*

The VN HUD reads "LOG · AUTO · LEWATI · MENU" in Indonesian instead of "RIWAYAT · OTOMATIS", and the
quick save buttons read "Q.SIMPAN · Q.MUAT". The in-game menu still says "Riwayat".

- **Why:** the HUD shares one row with the chapter label, and "Auto"/"Log" are common in Indonesian games.

## The developer panel stays English

*2026-11-15. CE-01.*

The in-game menu entry and its "story reloaded" toast are localized. The panel itself (variables, jumps, story
check) is not.

- **Why:** it is a writing tool behind `StorySetup.developer`, off in release builds, so players never see it.
- **Revisit if** writers on a team want it in Indonesian.

## `cerita_tools` doesn't depend on the engine at runtime

*2026-11-15. Authoring toolkit §4.*

The toolkit has its own condition parser instead of calling `ConditionEvaluator` from cerita_core. It only needs
to know whether a condition parses and which names it reads, and it accepts `meta.ending.*` and `meta.flag.*`
before the engine does (CE-03). cerita_core is a dev dependency, used by the test that plays the compiled
Wrong Number.

- **Why:** CE-01 and CE-03 change cerita_core in parallel, and the toolkit must keep building and running while
  they land. Authors also run it without Flutter.
- **Cost:** the condition grammar exists twice.
- **Revisit if** the grammars drift. The round-trip test catches drift only for what Wrong Number uses, so a
  shared grammar package is the fix if conditions grow.

## Text in a multi-locale story always compiles to an object

*2026-11-15. Authoring toolkit §2.6, CE-01.*

With one locale, script text compiles to a plain string, so Wrong Number's JSON is unchanged. With more, it's
always `{locale: text}`, even when only the source locale is written. Plain YAML values in `profiles.yaml` and
`channels.yaml` (names, handles) stay plain strings, since they're the same in every language.

- **Why:** one shape per story is simpler for the engine and for diffs than switching shape as translations
  arrive.
- **Revisit if** CE-01 settles on omitting single-entry objects.

## Per-locale voice clips use the localized shape too

*2026-11-15. Authoring toolkit §2.2, CE-01 D5.*

`voice=vo_01.{locale}.mp3` and `voice.en=` compile `voice` (and a voice note's `uri`) to
`{"id": "...", "en": "..."}`, the same shape as localized text. A shared clip stays a plain string.

- **Why:** CE-01 D5 needs a clip per language with a shared fallback, and the contract only defines the text
  shape. Reusing it means the engine needs one resolver.
- **Revisit when** CE-01 picks the JSON for per-language clips. This is the open contract question.

## Every lint check is an error, even while drafting

*2026-11-15. Authoring toolkit §3.1, PRD D2.*

Only missing translations are warnings while drafting. Unreachable conversations, variables read but never set
and missing assets fail `lint` straight away.

- **Why:** PRD D2 says every check blocks release, and most of these are typos that are cheapest to fix at once.
- **Cost:** a half-written scene that nothing links to yet fails `lint`.
- **Revisit if** that gets in the way of drafting. Then make reachability a warning without `--release`.

## Effects belong to an item

*2026-11-15. Authoring toolkit §2.4.*

`+trust 5`, `set`, `toggle` and `remember` are body lines of a line, choice option or other item. There is no
standalone effect statement.

- **Why:** the engine on this branch has no item that only runs effects, and inventing one would change the
  schema. An effect on a `branch` or `->` is an error, since the engine jumps without executing it.
- **Revisit when** the engine gets an effect-only item (`main` has `STAGE` and script flow items).

## Playtime runs are bounds, not predictions

*2026-11-15. Authoring toolkit §3.2, PRD D3.*

The shortest run to an ending skips every conditional item, the longest shows every one and counts each loop
once. The critical path is the longest of the longest runs.

- **Why:** conditions aren't evaluated, so the toolkit can't know which conditional lines a real run shows.
  Bounds are honest and cheap. Pacing defaults (200 wpm, 4 s per choice, 8 s per input, 4 s per media item) are
  guesses until the M1 playtest calibrates them in `cerita.yaml`.
- **Revisit after** the M1 playtest if real runs sit far from the middle of the bounds.

## Smaller script calls

*2026-11-15. Authoring toolkit §2.*

- File names are written with their extension (`bg=pier_dusk.webp`). Defaulting extensions would make the
  compiled JSON depend on a setting authors forget about.
- `[default]` marks the timeout option instead of a number, so reordering options can't change it.
- `compile` never deletes stale `cvn_*.json` files. It warns, and `compile --check` fails on them.
- Asset checks are skipped with a note when no asset folder is set, and `--release` makes that an error.

## Deferred

- **Crossfade music.** On Android, only the music player may request audio focus. Another player that does
  makes the music lose focus for good, and audioplayers pauses it without resuming. A crossfade needs two
  music players playing at once, so one of them would have to play without focus, which hasn't been tested on
  a device. Until then, track changes fade out and then in.
- **Rollback in chat and call scenes.** These threads move on by themselves, so rolling back into one needs
  their pacing to pause and resume. It also needs a design for what the thread shows while paused.
- **Remembered facts in the developer panel.** It lists run and `persistent.*` variables only. Showing
  `meta.flag.*` there needs a read-only row, since memory can only be written with `meta_set`.

## Device checks

*2026-11-15, Android 14 emulator (arm64), profile build via `make install`.*

Checked on the device: rollback across a full app restart (back to the name prompt), tags typed into the name
showing as written, a tagged choice option rendering in italics and its backlog reply without tags, and auto
mode waiting while HIDE is on and resuming after.

Not yet checked: the desktop mouse wheel rollback, story hot reload on a device, and fades and volumes by ear.
See the backlog.
