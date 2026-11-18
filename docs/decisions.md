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
  Done: `LintIssue.path` names the option, route, effect or stage action, and the toolkit reports at its line.

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
The core linter applies the same rule, so `cerita lint` on the compiled folder agrees with `cerita_tools lint`.

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

## Wide flowchart rows wrap instead of scrolling sideways

*2026-11-15. Presentation modes §4. Backlog CE-07.*

The Chapters flowchart fits the screen's width and only scrolls down. Nodes are at least 136 dp wide, so a
360 dp phone gets two columns. A row with more nodes than columns wraps onto more lines, checkpoints first and
endings after, and lines into and out of a wrapped row run down the gaps between its columns. Every node is as
tall as the tallest reached node's text, measured in the player's language and text size, so titles get two lines
and the endings count is never cut.

- **Why:** Last Seen's last row holds 7 endings and the whole story has 10. Fitting them in one row made nodes
  84 dp wide on a phone, which cut "0 dari 4 ending ditemukan" and titles, and pushed the fourth ending of Wrong
  Number off a 360 dp screen while the trunk stayed centered. Sideways scrolling would put most of a 10-ending
  row out of sight, and zooming to fit makes the text unreadable. Wrapping keeps one scroll direction, and
  endings are leaves, so the extra lines don't hide any route.
- **Cost:** in a wrapped row the lines share the gaps between columns, so it reads like a bus rather than one
  line per ending. Which checkpoint leads to an ending on a lower line is less obvious than in a single row. A
  title longer than two lines is cut with an ellipsis.
- **Revisit if** playtesters can't tell which checkpoint leads to an ending in a wrapped row. Then group a
  wrapped row's endings under their parent, or show the parent's name on a reached ending.

## Chat pacing scales the typing, not the pause after a message

*2026-11-15. Engine §5.3. Backlog CE-04, D2.*

`chat_pacing` multiplies how long the "is typing..." indicator shows: an explicit `typing_delay_ms`, or the
default typing time of a message without one. The pause after a delivered message, before the next one starts,
stays as it is. The Settings screen offers four steps: the story's pace, half, a quarter and instant.

- **Why:** the PRD defines chat pacing as the typing indicator's time. The pause after a message is the
  player's time to read it, and a chat moves on by itself, so cutting it would push lines past unread.
- **Revisit if** instant chats still feel slow in playtests. Then let a tap skip the pause, rather than
  scaling it.

## A story that can run out of items is a warning

*2026-11-15. Authoring tools §1.2.*

`StoryLinter` warns at the last item of a conversation the story enters at the top level when nothing after its
last entry point ends the story or leads on: no unconditional `ENDING`, `JUMP`, `RETURN`, `BRANCH` fallback, or
`CHOICE` whose options all have targets and one of them is always there, or evidence question whose responses,
`fallback` and `timeout` all have targets. Conversations only reached through `CALL` aren't checked, since running
out there returns to the caller.

- **Why:** the engine doesn't crash there. It ends the story with a plain "The End" and no ending is recorded,
  which is usually a mistake but can be a deliberate demo stop. Warnings already fail `cerita lint --strict` and
  `cerita_tools lint --release`, so a release can't ship with one.
- **Cost:** conditions aren't evaluated, so a route that always meets a conditional `JUMP` is reported anyway.
  Add an unconditional fallback, which also guards against the condition changing later.
- **Revisit if** authors get false warnings from `RETURN` in conversations that are both called and jumped to.
  `RETURN` counts as leading on, so a top-level `RETURN` with nothing to return to isn't reported.

## Clues are declared in `clues.yaml`, and scripts only award them

*2026-11-15. Authoring toolkit §1.4, §2.4. Backlog CE-02, CE-05.*

A story's clues live in `clues.yaml`, in story order, and compile to `clues.json`. In a script, `clue <id>` is an
effect line that sets `clue_<id>` to `true`, at column 0 (a `SET` where the scene finds it) or in any body that
takes effects, such as a choice option or an evidence outcome.

- **Why:** data schema §8 declares each clue once and has scenes only say it was found. A clue found on two routes,
  or only through a choice, would need a declaration in one script and bare awards elsewhere if declarations lived
  in the scripts. A YAML file next to `channels.yaml` keeps the board's order in one place.
- **Cost:** the title and description of a clue sit away from the scene that finds it.
- **Revisit if** authors keep forgetting to add new clues to `clues.yaml`. The lint error at the `clue` line
  already names the file.

## Evidence outcomes are `?` lines with a bracketed name

*2026-11-15. Authoring toolkit §2.2. Backlog CE-02, CE-06.*

Under `evidence`, `? <clue_id>` is a response and `? [retry]`, `? [fallback]` and `? [timeout]` are the outcomes.
The toolkit shows `clues.yaml` in place of `clues.json` in core lint messages.

- **Why:** an evidence question is a choice whose options are clues, so it reads like one. Brackets keep the
  outcomes apart from clue ids: a clue named `retry` is still a valid id. Authors never see `clues.json`.
- **Cost:** `[retry]` looks like the option modifiers (`[default]`, `[once]`), which don't apply here and are
  reported as an invalid answer.

## The evidence picker sits below the VN HUD, and no clue notification shows over it

*2026-11-15. Presentation modes §6.2, §6.3. Backlog CE-05, CE-06.*

In VN the picker fills the space under the HUD instead of the whole safe area, so the HUD stays visible and
usable above it. No "Clue found" notification shows while an evidence question is up, in any mode.
Notifications still queued when the question comes are dropped, not shown after it.

- **Why:** on an Android emulator the HUD was drawn over the picker and hid its prompt, the "pick a clue" line
  and the countdown for as long as the picker was open. A clue awarded right before the question also put its
  notification over the picker header for 3 seconds while the countdown ran. Hiding the HUD would also fix the
  overlap, but the backlog is the one place to read again what a witness said before presenting a clue, so
  the HUD stays and the picker moves. The notification has no free spot during the question, and tapping it
  opens the board, which the question hides on purpose. The clue isn't lost: the picker lists it, and it stays
  new, so the board's badge counts it once the question is answered. Showing it after the question would
  announce a clue the player has just looked at.
- **Cost:** the picker is shorter in VN by the HUD's height, about 90 dp in the anime skin. A skin with a very
  tall HUD leaves the picker little room. A clue found just before a question never gets its notification.
- **Revisit if** stories award clues in the line before a question and players miss them. Then the picker
  could mark clues found during this question.

## Settings slider values are as wide as their longest option

*2026-11-15. Backlog CE-04.*

The value next to each settings slider sits in a column measured from the longest option in the tile's text
style, capped at 120 dp. Text speed, auto-forward delay and chat typing share one column, built from all their
options in the active language, and the volumes share another. A value that still doesn't fit, e.g. at a large
text scale, is scaled down instead of wrapped. The labels themselves stay as they are.

- **Why:** the fixed 56 dp column wrapped "Story pace" in English and "Paling lambat", "Lebih cepat" and "Tempo
  cerita" in Indonesian. Shortening the labels would make them vaguer, and every new language would need to fit
  56 dp. Measuring all options, not the current one, keeps the slider the same length while it is dragged, and a
  shared column keeps the sliders lined up.
- **Cost:** the text sliders are roughly 30 dp shorter than before in Indonesian, and about 10 dp in English.
- **Revisit if** a language has a value label longer than 120 dp at the normal text scale. It would show
  scaled down.

## A finished playthrough leaves no autosave

*2026-11-15. Engine §5.2. Backlog CE-08.*

The autosave was written after every item, including the `ENDING` item, and loading a save that stops at an
ending shows the summary again. So after finishing, the title screen still offered Continue, named after the
ending's chapter, and it only led back to the summary. Now the controller deletes the autosave when the
playthrough reaches an `ENDING` (or the story runs out of items), so a finished story offers no Continue until
a new game starts.

- **Why:** Continue should lead somewhere new. Skipping the write at the ending instead would leave the
  autosave on the line before it, which replays the ending and is worse.
- **Kept:** a manual or quick save made on the ending summary still reopens it, as it always has. Rolling
  credits don't change anything here: both ending paths leave no autosave, and a widget test checks that.
- **Cost:** after finishing, a player who wants to see the summary again uses the Endings screen.
- **Revisit if** players want to pick up right after an ending, e.g. for a post-ending epilogue.

## The demo's own title strings stay in the demo

*2026-11-15. Example app.*

The title screen's Features and Reset entries and the reset dialog are translated by a small map in
`example/lib/home_screen.dart`, keyed by the active story locale, with English as the fallback. The Features
screen itself and the subtitle stay in English.

- **Why:** `CeritaStrings` is for strings every app built on the engine needs. A demo-only entry there would
  make every app and every added language carry it. The Features screen lists engine capabilities for
  developers, not story text.
- **Revisit if** the demo gets more app strings or more languages. Then a demo strings class like
  `CeritaStrings` would be cleaner than a map.

## Choice options can be silent

*2026-11-17. Data schema §4.4, authoring tools §1. Found in the Last Seen M1 playtest.*

In a chat, the picked option is always sent as the player's message. Last Seen's prologue has a choice whose
options are actions ("Type \"sorry\"", "Close the app"), so the action itself showed up as a sent bubble. Three
other chats write the reply as an option and then as a scripted player line with chat casing and a send sound,
so it showed up twice. Options and choices now take `silent`, which sends nothing, and the linter warns when a
chat option that isn't silent is followed by a player line.

- **Why a flag and not a rule:** the engine can't tell an action from a message, and a scripted line right after
  a choice is sometimes a different line on purpose. A flag keeps the author in charge, and the lint warning
  catches the common mistake.
- **Why not drop the scripted lines instead:** they carry the chat voice (lower case, slang) and the send sound,
  which the option text shown on a button shouldn't have.
- **Cost:** one more flag to remember. The warning covers the case that matters.
- **Revisit if** authors want a reply that differs from the button text without a scripted line, e.g. a
  `reply` field per option.

## Characters stand side by side on a portrait stage

*2026-11-17. Presentation modes §2. Found in the Last Seen M1 playtest.*

*Its width cap was replaced on 2026-11-18, see "A portrait crowd overlaps instead of shrinking".*

On a phone held upright, a sprite drawn at 82% of the stage height is as wide as the stage, so the `left` and
`right` slots couldn't move it and two characters both landed in the middle, one hidden behind the other. Every
speaker change then swapped which one was in front in a single frame, and an expression change cross-faded both
sprites to half opacity, so the character behind showed through. Now a sprite is capped to a share of the stage
width when several characters are on stage, the paint order stays fixed, and an expression change fades the new
sprite in before the old one fades out.

- **Why side by side and not only the speaker:** scripts say who is on stage, and a reply lands better when the
  listener stays visible. Dimming already shows who speaks.
- **Cost:** with two characters on a phone, each is smaller, about 60% of the stage width. A lone character
  keeps its size, and landscape stages don't change because their sprites are already narrower than the cap.
- **Revisit if** a story needs close-ups of two people at once. A per-scene option to show only the speaker
  would fit there.

## Characters spread edge to edge on a portrait stage

*2026-11-17. Presentation modes §2. Found in the Last Seen M1 bug sweep.*

*Replaced on 2026-11-18, see "A portrait crowd overlaps instead of shrinking".*

With two or more characters on a stage narrower than it is tall, they are placed evenly from edge to edge in
slot order instead of at the fixed slot positions, and the width cap eases to its new value over the sprite
transition when someone enters or leaves.

- **Why:** a phone held upright has no room for five slots. `far_*` slots pushed a third character off screen and
  `center` covered most of `left`. A cap that changed in one frame made everyone jump about 30% in size.
- **Cost:** on a phone `left` and `center` look the same as `left` and `right`, and a character slides when
  another enters further out. The character layer rebuilds every frame for about 250 ms during the ease.
  The zoom focus still uses the landscape slot positions.
- **Revisit if** a story needs exact slot placement on phones, or profiling shows the eased rebuild.

## Off-stage speakers and who comes on stage by speaking

*2026-11-17. Data schema §4.1, §4.4. Found in the Last Seen M1 bug sweep.*

A `TEXT` line can be `offstage` (`[offstage]` in scripts): it shows the speaker's name, dims everyone on stage
and leaves the stage as it is. Only a `TEXT` speaker comes on stage by speaking. A `CHOICE`, `INPUT` or `MEDIA`
speaker changes expression if already there, but is never added.

- **Why:** Last Seen plays recordings of a missing character. Her sprite walked into rooms she isn't in and
  pushed the protagonist out. A prompt's asker is often the point-of-view character, and with no position on
  those items they always landed at center.
- **Cost:** a script that relied on a choice speaker appearing now needs a `stage show`.
- **Revisit if** off-screen voices need their own look, such as a nameplate style.

## The reply-twice check plays the story forward

*2026-11-17. Authoring tools §1.4.*

The double-reply lint now follows what plays after a chat option: it applies the option's `value` and effects,
walks past items the player doesn't see, follows jumps, calls and labels into other conversations, and works out
the scene of a conversation that has none from the conversations that lead to it. It reports only when a player
line definitely plays next.

- **Why:** strict lint fails CI, and the first version flagged options whose player line was gated on another
  answer, with advice that would have removed the only reply.
- **Cost:** a condition that reads anything the pick didn't set stops the check without a report, so a mixed
  condition like `R == 'no' && trust > 2` isn't checked. Scene-less conversations entered from different scenes
  aren't checked, and every `WAIT` is walked past, even one with a notification.
- **Revisit if** real double replies slip through. A three-valued evaluator would close the gap.

`silent` on a `choice` line is always the keyword. `choice silent silent` is an error, and lint reports a bare
`choice silent` when the story reads a variable named `silent`, which catches scripts that meant a variable.

## INPUT digits and length

*2026-11-17. Data schema §4.5.*

`INPUT` takes `keyboard` (`text` or `digits`), `min_length` and `max_length` (`keyboard=digits length=4` in
scripts). The answer is still text, so "0530" keeps its leading zero, and the send button waits until it fits.

- **Why:** Last Seen asks for a four-digit code and a letter keyboard opened and accepted any length.
- **Cost:** with `min_length`, an empty answer can't fall back to `default_value`.
- **Revisit if** stories need decimals, signs or a masked PIN field.

## The chat header shows the time and a status, not the day

*2026-11-17. Presentation modes §1.1, data schema §3.*

The chat subtitle shows the scene time first, in the player's language ("11:58 PM", "23.58"), then the status,
wrapping to a second line before anything is cut. It no longer shows the day. A scene can override the
channel's status with `status`, or hide it with `null` (`status=none` in scripts). The VN HUD uses the same clock.

- **Why:** "Day 0 · 02:1…" cut off the time, "Day 0" read oddly, and a flashback showed the thread's present-day
  "last seen" while the contact was still typing.
- **Cost:** a slightly taller app bar, and the day is gone from the chat header.
- **Revisit if** players lose track of the day in long chat-only stretches.

## No engine "Call ended" duration

*2026-11-17. Presentation modes §1.*

The engine doesn't add a call-duration line. Stories write their own "Call ended" line and don't state a
duration.

- **Why:** the call timer is real time, which means nothing under skip, auto or after a load, and isn't saved.
  A story's hard-coded duration contradicted the timer.
- **Revisit if** call records become a feature, like a "Voice call · 0:43" line in the thread.

## Didit first writes on Day 3

*2026-11-17. Last Seen spec §2, M2 beat plan §8.*

Didit's first contact moves from Day 4 to Day 3, as a chat. Day 4 keeps his first call. The early bad end
*Handed Over* is sending him the spare phone by courier.

- **Why:** the Day 3 bad end needs someone to hand the phone to, and Didit is chat and call only, so he can't
  come to the house.
- **Cost:** Day 3 carries four threads (the auction, Hendra, Yusuf, Didit), so it's the fullest day of M2.
- **Revisit if** the M1 playtest shrinks the day budgets enough that Day 3 can't hold all four.

## A chat thread can be on another character's phone

*2026-11-17. Data schema §2, presentation modes §1.1.*

A thread in `channels.json` takes an `owner`, a profile id. The owner's messages in it sit on the outgoing side
like the player's, without avatar, name or typing indicator. The header still shows the thread's contact.

- **Why:** Last Seen's Day 2 reads Sekar's threads on her phone. Her messages there are the ones she sent, and
  showing them as incoming made her phone look like Raka's.
- **On the thread, not the scene:** a thread's history is shown across every scene that uses it. An owner per
  scene would flip old bubbles from side to side when a later scene left it out.
- **Cost:** the player's own replies in such a thread are outgoing too, so a choice there reads as the owner
  sending it. That fits Raka typing on Sekar's phone.
- **Revisit if** a story needs one thread seen from two phones. That is two threads today.

## Public domain recordings count as CC0 for Last Seen's sound

*2026-11-17. Last Seen spec §6.*

Three M2 sounds (the harbor, the generator night and the courier's motorbike) come from PDSounds recordings on
Wikimedia Commons, marked public domain by their authors. `credits.json` lists them as "Public domain" with the
Commons page as the source.

- **Why:** the spec asks for CC0 so the sound needs no attribution rules. A public domain release gives the same
  freedom. OpenGameArt had no CC0 harbor, motorbike or diesel recordings, and freesound downloads need a login.
- **Not accepted:** "free" sounds without a stated license, CC-BY, Pixabay, and packs whose CC0 label is doubtful
  (an OpenGameArt gull pack ripped from a video was skipped).
- **Revisit if** a store review or the M5 license pass wants CC0 by name. The three files would then be replaced.

## A call ends where `hangup=` leads, or can't be ended

*2026-11-17, changed 2026-11-18. Presentation modes §1.2, data schema §3.*

A `CALL` scene with `ring=` rings until the player answers, and its first line waits for the answer. Every call
button works: mute, speaker and the keypad are the player's own, and hold stops the line and the story. Ending or
declining the call goes where the scene's `hangup=` target leads, after "Call ended" shows for 1.2 seconds.
Without `hangup=` the call can't be ended: a narration card says what the player's character thinks of hanging up
(the scene's `stay=` line, or the engine's "Not now. I need to hear this."), and the call goes on.

- **Why:** the first version made the caller call back after a hang-up. The playtest found that odd: the story
  should say why the character stays on the line, in their own voice, and a call that can be skipped should be
  the engine's job, not a callback trick.
- **Dinda's call** can't be ended. Raka thinks "Don't. Dinda wouldn't call at this hour unless it mattered."
- **Mute and speaker change nothing in the story.** They are there for the feel of the phone.
- **Cost:** a declined ringing call that has a `hangup=` target drops its first line, which the engine has
  already put in the backlog.
- **Revisit if** a puzzle wants tones typed during a call. The keypad plays the platform's key click, not real
  phone tones, because the engine ships no sounds.

## The outgoing scene is frozen while it fades out

*2026-11-17. Presentation modes §1 and §2.*

During a scene switch the outgoing view is shown as a snapshot of how it last looked.

- **Why:** the views read the story state as it is now, which already holds the incoming scene. The call view
  redraws every second for its timer, so after Dinda's call the outgoing call lost its background and caption
  mid-fade. Any rebuild of the outgoing view (a language switch, a line still typing) had the same risk.
- **Cost:** anything animated in the outgoing scene stops for the 0.45 s it takes to fade out.

## A chapter card that comes with its scene starts fully shown

*2026-11-17.*

When a scene arrives with a chapter card, the card is up from the scene's first frame and the scene fades in as
the card. A new chapter in a scene already on screen still fades its card in over it.

- **Why:** the card used to start its own fade in after the scene had faded in, so the new scene showed for a
  moment and was then covered. The playtest called the Prologue's start and the switch after Dinda's call
  glitchy.
- **Cost:** the card fades in 0.5 s sooner and is shown that much longer behind the scene transition.

## Sprites stand on the bottom edge of the stage

*2026-11-17. Presentation modes §2.1.*

A sprite sits at the bottom of its slot. Before, the expression cross-fade centered it, and on a portrait stage
the slot is taller than the sprite, so the cut-off legs floated about 110 dp above the screen edge. The title
screen showed it most.

Holding the stage (or the title screen) hides the UI until the finger lifts, so the art can be seen whole.

## The cast shares one scale, from each character's height and framing

*2026-11-18. Presentation modes §2.1, data schema §2. Found in the Last Seen M1 playtest.*

*Its `framing` was replaced the same day, see "Sprites are sized by their heads".*

A profile can give its `height` and its sprites' `framing` (the share of the body they show from the top of the
head). The stage sizes every sprite with one scale for the whole cast, so the tallest head reaches 82% of the
stage, a shorter character stands shorter, and each sprite's cut sits below the bottom edge at its height above
the floor. Without heights every sprite is as tall, as before.

- **Why:** every Last Seen sprite fills the same 887 × 1774 canvas, but they are cut at different points: Raka's
  at the knee, Dinda's and Yusuf's at the thigh. Drawn at one height, Raka's head came out smaller than theirs
  although he is the tallest. Only the writer knows how tall a character is, and the cut can't be read from the
  image, so both are data.
- **Why the whole cast and not who is on stage:** sizes measured on the people present would change when
  someone walks in. With the cast measured once, a character keeps their size all story.
- **Last Seen's numbers** are estimates from the sprites' landmarks: Raka 178 cm, framing 0.72; Bima 180, 0.63;
  Yusuf 175, 0.62; Hendra 168, 0.62; Tasya 165, 0.64; Sekar 162, 0.68; Dinda 156, 0.62. Tune them in
  `profiles.yaml` if a pair looks off.
- **Cost:** a short character alone has more background above them. The writer has two numbers to fill in per
  character.

## A portrait crowd overlaps instead of shrinking

*2026-11-18. Presentation modes §2.1. Replaces "Characters stand side by side" and "Characters spread edge to edge" for portrait stages.*

On a portrait stage the camera barely pulls back for a crowd (80% with two, 66% with three) and the characters
overlap, half the stage width apart with two and 34% with three. On a landscape stage the slots are fixed
shares of the width and the far ones are half on screen.

- **Why:** the width cap shrank two characters to 60% of the stage width, small against the background. The
  playtest found the proportions off. Overlap reads as people in one shot, and the dimming shows who speaks.
- **Also fixed:** on a landscape phone the `far_*` slots put their character fully off screen.
- **Three, tuned after the second playtest:** at 72% and 40% the middle one hid most of the one at the side and
  pushed the other half off the screen. At 66% and 34% all three faces are clear and nobody is a doll.
- **Cost:** with three on a phone the middle one covers part of the other two. The paint order stays fixed, so
  the speaker can be behind someone.
- **Revisit if** a scene with three needs everyone fully visible: a per-scene option to show only the speaker
  would fit there.

## A scene that ends by itself waits for a tap

*2026-11-18. Presentation modes §7.1, engine `peekExit`.*

When a scene would end with nothing but the clock moving it on (chat pacing, a `wait`, a stage direction), the
story stops with a "Tap to continue" prompt before the next scene. The engine looks ahead without moving
(`RealFsseEngine.peekExit`) to see whether the next item is in another scene.

- **Why:** chats ended and cut to the next scene a second after their last message, which the playtest found
  too fast. A VN line already waits for a tap, so only these ends needed one.
- **What counts as another scene** follows what the player sees switch: another mode or thread, any new VN
  conversation, a new chapter, or the end. A chat continuing in the same thread doesn't wait.
- **Auto and Skip don't wait.** The player asked the story to move for them.
- **Cost:** the look-ahead reads conditions as they are now, without the effects of `SET` items on the way. A
  route that a `SET` just before the end decides may be judged wrong, and then the scene doesn't wait.

## Holding a control doesn't hide the UI

*2026-11-18. Presentation modes §2.1.*

Holding the stage hides the UI, but a hold that starts on a button, a choice or a menu entry does nothing. A
control is anything with a `MouseRegion` under the finger, which every `InkWell` and Material button has. Last
Seen's own buttons (the MENU tag, choices, menu rows, title menu) are `GestureDetector`s, so they now sit in a
`MouseRegion` with the click cursor.

- **Why not the click cursor alone:** on Android an `InkWell`'s cursor resolves to the basic arrow, so the cursor
  says nothing on a phone. The region itself is there on every platform.
- **Cost:** a skin's button made of a bare `GestureDetector` still peeks until it gets a `MouseRegion`.

## Every bottom sheet shares one frame

*2026-11-18. Presentation modes §7.2.*

The in-game menu, the backlog, a clue's detail, the route chart's chapter actions and the developer tools open
through `StorySheet.show`, which the skin draws with `StorySkin.sheet`: a handle, an icon and title, a close
button and a rule. A sheet is as tall as its body, between 40% and 88% of the screen. A picture opened full
screen (a clue's image, a chat photo, a gallery CG) is a sheet too, the whole screen tall. Last Seen draws it as
its framed retro window.

- **Why:** the playtest asked for nicer sheets, the Case Board's most of all. They were stock Material panels
  in a pixel-art game, the backlog opened at 80% height with one line in it, and the menu ran past the screen.
- **The menu** puts Save, Load, Case Board and Backlog in a row of big buttons and the rest in a short list.
- **The 40% floor:** a sheet as tall as one line read as a strip at the bottom of the screen, not a panel (second
  playtest note). The floor keeps every sheet the same kind of object, and the body starts at its top.
- **The picture viewer** was a black page with an app bar, the one screen that looked like a stock app. As a sheet
  it keeps the skin's frame and closes like the rest.
- **The picture grows out of its thumbnail** (third playtest note). A Hero can't do it: Flutter flies heroes only
  between page routes, and the clue's thumbnail sits in a modal sheet. So the viewer has its own route, which
  fades the skin's frame in, and the picture flies above the fade from the thumbnail's box to its fitted box in
  the viewer, cropped like the thumbnail at the start. The viewer's own copy shows once it lands.

## Sprites are sized by their heads

*2026-11-18. Presentation modes §2.1, data schema §2. Found in the second Last Seen playtest. Replaces `framing`.*

A profile gives `head: {top, chin}`, where the top of the hair and the bottom of the chin are on its sprites, as
shares of the sprite height. The stage takes the head as 1/6 of the character's height with the top of the hair at
that height. From that it knows how long the whole sprite is in the cast's unit and where it stands, so every head
comes out in proportion to its character.

- **Why:** `framing` (the share of the body a sprite shows) was a guess from where the art cuts, and it was off
  where it mattered. The art draws Raka with a small head on a long frame, so he looked shorter than Dinda. Players
  compare heads, not knees, so the head is what has to come out right. A head is also easy to measure, where a body
  cut isn't.
- **Why the whole head and not the face:** the first try measured eyes to chin, as 1/15 of the height. It made
  Dinda look big-headed: the art draws the girls with big eyes set low and a short chin, and Bima with a long jaw,
  so Dinda's whole head is 3.1 times her eyes to chin and Bima's 1.8 times. Sized by the face, her head came out
  half again as big as his. Side by side with the whole head and a mix of both, the whole head looked right.
- **Also found:** the story stage never passed the heights to the stage at all, only the probe that rendered it
  for screenshots did. On the phone every character was drawn as tall as the tallest and head to toe, which
  zoomed everyone into a chest-up close-up. A test now checks the story stage hands each actor its profile's
  height and head.
- **Last Seen's numbers** were measured on the neutral poses: the top as the first opaque row, the chin by eye.
  The other poses match within a few pixels, except where a hand is raised above the head.
- **Cost:** one measurement per character, and a character whose poses are drawn at different scales needs them
  redrawn to match. Hair counts, so a character with big hair or a hat (Hendra's cap) comes out a little smaller
  than their height says.

## A new expression waits for its image

*2026-11-18. Presentation modes §2.1. Found in the second Last Seen playtest.*

When a character changes expression, the cross-fade starts once the new sprite is decoded. Until then the old one
stays on screen.

- **Why:** a pose not shown before takes a moment to decode on a phone, and the 240 ms cross-fade faded the old
  one out on time over an empty slot. The character blinked out mid-change, but only the first time each pose
  showed, which made it look random.
- **Cost:** a first-time pose arrives a few frames after its line.

## Clue notifications show under the VN HUD

*2026-11-18. Presentation modes §6.*

In VN the "Clue found" notification slides in under the HUD instead of over it. A bar wrapped in
`ClueNotifications.below` reports where it ends, and the notifications show below the lowest one.

- **Why:** for 3 seconds the notification covered MENU, the backlog and the other quick controls.
- **Not in chat:** the chat header has nothing the player needs in those 3 seconds.

## bgm_unease loops at a quiet join

*2026-11-18. Last Seen assets.*

The track's first and last samples held the three largest jumps of the whole file, a click baked in at both
edges, heard as a tick every 48 seconds. The loop point now sits at a zero crossing in the middle of the track,
the old ends are joined inside the file with a 10 ms crossfade, and the file is encoded at 96 kbps. Its edges
now step no more than the music does next to them.

## Deferred

- **Crossfade music.** On Android, only the music player may request audio focus. Another player that does
  makes the music lose focus for good, and audioplayers pauses it without resuming. A crossfade needs two
  music players playing at once, so one of them would have to play without focus, which hasn't been tested on
  a device. Until then, track changes fade out and then in.
- **Rollback in chat and call scenes.** These threads move on by themselves, so rolling back into one needs
  their pacing to pause and resume. It also needs a design for what the thread shows while paused.

## Device checks

*2026-11-15, Android 14 emulator (arm64), profile build via `make install`.*

Checked on the device: rollback across a full app restart (back to the name prompt), tags typed into the name
showing as written, a tagged choice option rendering in italics and its backlog reply without tags, and auto
mode waiting while HIDE is on and resuming after.

Not yet checked: the desktop mouse wheel rollback, story hot reload on a device, and fades and volumes by ear.
Also not yet checked: the ringtone loop of a `ring=` call, the vibration while it rings, the keypad click,
holding the stage to hide the UI (and holding a button not hiding it), and the cast's heights on a real phone.
See the backlog.
