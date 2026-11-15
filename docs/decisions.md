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
See the backlog.
