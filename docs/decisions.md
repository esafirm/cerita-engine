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

## `cerita_tools` stays its own package, and lints through core's `StoryLinter`

*2026-11-15. Authoring toolkit §3.1, authoring tools §1.*

The toolkit's commands stay under `cerita_tools` instead of moving into cerita_core's `cerita` command.
`cerita_tools lint` compiles the story and runs `StoryLinter` on the JSON, once per locale, and maps each issue
back to the script line of the item it's about. The toolkit only adds checks for what exists in the scripts
alone: syntax, speaker and expression names, unused cast, missing translations. It has no condition parser of
its own any more.

- **Why:** cerita_core is the engine and runs on the web, while the toolkit reads YAML and script folders from
  disk and only matters to authors. One linter means a check added for JSON stories also covers scripts, and the
  two can't disagree about what a valid story is.
- **Cost:** cerita_tools now depends on cerita_core at runtime. A JSON check can only point at an item's
  header line, not at the exact body line, since the engine reports item indexes.
- **Revisit if** core issues need finer positions (an option index, a field name). `LintIssue` would need them.

## `lint` compiles partially so both layers report in one run

*2026-11-15. Authoring toolkit §3.1.*

When a script has errors, the linter still compiles it without the broken statements, writing `""` for missing
required text, and runs the story checks on the result.

- **Why:** PRD 10.3 asks for every error, not just the first. Without this, one typo hides every JSON problem
  until it's fixed.
- **Cost:** a broken statement that was dropped can cause a knock-on issue, such as a label nothing defines.

## Text in a multi-locale story always compiles to an object

*2026-11-15. Authoring toolkit §2.7, CE-01.*

With one locale, script text compiles to a plain string, so Wrong Number's JSON is unchanged. With more, it's
always `{locale: text}`, even when only the source locale is written. Plain YAML values in `profiles.yaml` and
`channels.yaml` (names) stay plain strings, since they're the same in every language. CE-01 accepts single-key
objects.

- **Why:** one shape per story is simpler for the engine and for diffs than switching shape as translations
  arrive.

## Voice follows CE-01's file name convention

*2026-11-15. Authoring toolkit §2.2, CE-01 D5, data schema §5.4 on the CE-01 branch.*

`voice=` and a voice note's file stay one file name. The player tries `name.<locale>.mp3`, then `name.mp3`, so
the script has no per-locale voice syntax. `tts-manifest` names each entry's output `name.<locale>.mp3`, and an
asset check passes with either the shared file or every locale's own file.

- **Why:** CE-01's design. An earlier draft of the toolkit compiled per-locale clips to a locale object, which
  CE-01 didn't adopt.

## `--release` fails on warnings

*2026-11-15. Authoring toolkit §3.1, PRD D2.*

While drafting, issues keep the severity the linter gives them: core's warnings (unreachable conversations,
variables read but never set) and the toolkit's (missing translations, unused cast) don't fail `lint`. With
`--release`, every warning is an error, like `cerita lint --strict`.

- **Why:** PRD D2 says every check blocks release builds, and drafting needs room for half-linked scenes and
  untranslated lines. This replaces the first draft, where every toolkit check was an error even while drafting.

## Effects stand alone as `SET`

*2026-11-15. Authoring toolkit §2.4.*

An effect line at column 0 compiles to a `SET`, and effect lines that follow each other share one. `set` with
a body is the form that takes `[if]` and `label=`.

- **Why:** most state changes sit between lines, and a `set` keyword on each one is noise. Merging keeps the JSON
  close to what a person would write.
- **Cost:** two consecutive effect lines can't become two `SET`s without something in between.

## Playtime runs are bounds, not predictions

*2026-11-15. Authoring toolkit §3.2, PRD D3.*

The shortest run to an ending skips every conditional item, the longest shows every one and counts each loop
once. The critical path is the longest of the longest runs. A `CALL` counts the whole called section, from its
target to a `RETURN`.

- **Why:** conditions aren't evaluated, so the toolkit can't know which conditional lines a real run shows.
  Bounds are honest and cheap. Pacing defaults (200 wpm, 4 s per choice, 8 s per input, 4 s per media item) are
  guesses until the M1 playtest calibrates them in `cerita.yaml`.
- **Revisit after** the M1 playtest if real runs sit far from the middle of the bounds.

## Smaller script calls

*2026-11-15. Authoring toolkit §2.*

- File names are written with their extension (`bg=pier_dusk.webp`). Defaulting extensions would make the
  compiled JSON depend on a setting authors forget about.
- `[default]` marks the timeout option instead of a number, so reordering options can't change it.
- `-> target` is a `JUMP`. A `BRANCH` with only a fallback is written as `branch` with a `-> target` body, which
  Wrong Number needs to compile to its hand-written JSON.
- `compile` never deletes stale `cvn_*.json` files. It warns, and `compile --check` fails on them.
- Asset checks are skipped with a note when no asset folder is set, and `--release` makes that an error.

## A clue is found when `clue_<id>` is true

*2026-11-15. Data schema §8.1, engine §10. Backlog CE-05.*

Clues are declared in `clues.json`, but finding one is an ordinary effect on the playthrough variable
`clue_<id>`. There is no new item type, effect op or clue set in the save.

- **Why:** saves, checkpoints, scene replay and rollback already restore variables, which is exactly the
  lifetime the PRD asks for (D1). Conditions like `clue_pier_photo == true` work as they are, and CE-02's
  `clue` keyword only has to compile to one effect.
- **Cost:** the `clue_` prefix is reserved in stories that have a `clues.json`, and a story can take a clue
  away by setting it to `false`, which the PRD says shouldn't happen.
- **Revisit if** authors trip over the prefix, or a story needs clues that can't be unset. Then add an
  `award` op that only ever sets `true`, and have the linter flag other writes.

## Retries only cover clues without a response

*2026-11-15. Data schema §4.4. Backlog CE-06.*

A clue listed in `responses` always plays its response, which is final. Only the other clues are wrong
answers that use a retry (`retry` plays) until none remain (`fallback` plays). Running out of time plays
`timeout` and doesn't use a retry.

- **Why:** the PRD's acceptance test is "the retry plays after the first wrong clue and the fallback after the
  second", which needs one retry outcome and one final outcome. Letting a specific response also be a retry
  would need a second target per response, one for "ask again" and one for "no tries left".
- **Cost:** a specific reply that leads back to the question (Tasya brushing off the pier photo) lets the
  player try again without using a retry.
- **Revisit if** a deduction needs a specific wrong reply that also counts against the limit. A per-response
  `"wrong": true` could route it through the retry count.

## An evidence question with no clue found plays its fallback

*2026-11-15. Engine §10.2. Backlog CE-06 open question.*

The question isn't shown. Its `fallback` plays straight away, as if a wrong clue was presented with no
retries left.

- **Why:** the PRD recommends it, and an empty picker would be a softlock. The linter reports questions that
  can be reached before a clue with a response is awarded, so a finished story shouldn't hit it.

## Viewed clues live in the save, not in rollback frames

*2026-11-15. Engine §10.2. Backlog CE-05.*

Which clues the player has seen on the board is saved per playthrough (`viewed_clues`). Closing the board
marks everything it showed as viewed. Rollback leaves it alone, and a checkpoint or an old save counts every
clue already found as viewed.

- **Why:** "new" is about what the player has looked at, not about story state, so going back a line shouldn't
  make a clue new again. Marking on close means the player doesn't have to open every clue to clear the badge.
- **Revisit if** players miss clues because opening the board clears them. Then mark a clue viewed only when
  its detail is opened.

## Credits roll when the player leaves the ending summary

*2026-11-15. Presentation modes §4, data schema §9. Backlog CE-08.*

An ending listed in `roll_after` shows its summary as usual. Tapping Back to title or All endings rolls the
credits first, then goes there. The endings that roll credits are listed in `credits.json`, not marked on the
`ENDING` item.

- **Why:** the PRD wants credits after the summary. Starting them on a timer would cut the summary short for slow
  readers, and leaving is the moment the player is done with it. Keeping `roll_after` in the credits file needs
  no new item field and no script syntax, and the linter checks the ids.
- **Revisit if** a story wants credits before its summary, or in the middle of the story. Then an item or a
  `STAGE` action would roll them.

## `credits.json` is written by hand, also for script stories

*2026-11-15. Data schema §9, authoring toolkit §2.8. Backlog CE-08.*

`cerita_tools` doesn't compile or lint credits. A script story keeps a hand-written `credits.json` in its output
folder next to the compiled files, and `cerita lint` on that folder checks it. `compile` never deletes it, since
it only warns about stale `cvn_*.json` files.

- **Why:** credits are a short list with no dialogue, references or translations to keep in step with the
  scripts. A YAML form would only change the brackets.
- **Revisit if** Last Seen's credits grow long enough to want comments, or authors forget to lint the output
  folder. Then add `credits.yaml` to the story folder and compile it like `channels.yaml`.

## Wrong Number ships without credits

*2026-11-15. Backlog CE-08.*

The demo has no `credits.json`, so its title screen shows no Credits entry. The screen and rolling credits are
covered by widget tests with a fixture instead.

- **Why:** the sources and licenses of the demo's art, music and voices aren't recorded anywhere, and credits
  that guess them would be wrong.
- **Revisit when** the demo assets' sources are known: add a `credits.json` and a `roll_after` for the true ending.

## The route map's nodes are checkpoints, not chapters

*2026-11-15. Authoring tools §2.1, presentation modes §4. Backlog CE-07.*

The Chapters flowchart draws one node per checkpoint conversation and one per `ending_id`. Conversations that
aren't checkpoints (call scenes, shared subroutines, ending scenes) fold into the checkpoint that leads to them.
Routes that loop back to an earlier checkpoint count for "endings found" but aren't drawn.

- **Why:** a checkpoint is what the player can replay from, which is the point of the chart. Grouping by the
  `chapter` text would merge two routes that are both called "Day 5", which is exactly the split the PRD wants
  to show. Lines drawn back up the chart cross every row and make a phone-sized chart hard to read.
- **Cost:** a route split inside a chapter, without a checkpoint at the split, shows as one node with several
  endings below it. Authors put checkpoints at the major beats, as the PRD asks.
- **Revisit if** a story needs non-checkpoint scenes on the chart, or loops matter to players. Then draw loops as
  a side marker on the node rather than a line.

## The Chapters view isn't remembered

*2026-11-15. Presentation modes §4. Backlog CE-07, D1.*

The flowchart/list switch lasts until the screen closes. Opening Chapters again picks the default: the flowchart
for a branching story, the list otherwise.

- **Why:** D1 sets a default per story, and a stored preference would be one more player setting for a screen
  visited a few times per run.
- **Revisit if** playtesters switch to the list every time.

## Chat pacing scales the typing, not the pause after a message

*2026-11-15. Engine §5.3. Backlog CE-04, D2.*

`chat_pacing` multiplies how long the "is typing..." indicator shows: an explicit `typing_delay_ms`, or the
default typing time of a message without one. The pause after a delivered message, before the next one starts,
stays as it is. The Settings screen offers four steps: the story's pace, half, a quarter and instant.

- **Why:** the PRD defines chat pacing as the typing indicator's time. The pause after a message is the
  player's time to read it, and a chat moves on by itself, so cutting it would push lines past unread.
- **Revisit if** instant chats still feel slow in playtests. Then let a tap skip the pause, rather than
  scaling it.

## Deferred

- **Crossfade music.** On Android, only the music player may request audio focus. Another player that does
  makes the music lose focus for good, and audioplayers pauses it without resuming. A crossfade needs two
  music players playing at once, so one of them would have to play without focus, which hasn't been tested on
  a device. Until then, track changes fade out and then in.
- **Rollback in chat and call scenes.** These threads move on by themselves, so rolling back into one needs
  their pacing to pause and resume. It also needs a design for what the thread shows while paused.
- **Remembered facts in the developer panel.** It lists run and `persistent.*` variables only. Showing
  `meta.flag.*` there needs a read-only row, since memory can only be written with `meta_set`.
- **"Story stops" check.** A route that runs out of items without an ending, jump or caller makes the engine
  throw `EndOfStoryException`. The first toolkit draft checked this on scripts, but it's a JSON check, so it
  belongs in `StoryLinter`, where `cerita_tools lint` picks it up. Until then neither linter reports it.

## Device checks

*2026-11-15, Android 14 emulator (arm64), profile build via `make install`.*

Checked on the device: rollback across a full app restart (back to the name prompt), tags typed into the name
showing as written, a tagged choice option rendering in italics and its backlog reply without tags, and auto
mode waiting while HIDE is on and resuming after.

Not yet checked: the desktop mouse wheel rollback, story hot reload on a device, and fades and volumes by ear.
See the backlog.
