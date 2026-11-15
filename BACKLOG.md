# Backlog

Work that is known but not scheduled. Specs come first: update `specs/` before the code, like the rest of the engine. Why an item was deferred, and the calls made while finishing others, are in [`docs/decisions.md`](docs/decisions.md).

## Polish

- **Crossfade music.** Track changes fade out, then in, because a second music player would take Android audio focus from the first. A crossfade needs a player setup that shares focus.
- **Rollback in chat and call scenes.** Rollback stops at chat and call threads, which move on by themselves. It would need their pacing to pause and resume.
- **Device check.** Rollback, text tags and HIDE were checked on an Android emulator (see the decisions log). Fades and volumes still need a listen on a device, and the mouse wheel rollback and story hot reload a run on a desktop and a device. The Chapters flowchart (layout on a narrow phone, sideways scroll of a wide row), rolling credits and chat typing pace haven't been seen on a device yet.

- **Case Board in the demo.** Wrong Number has no clues, so the Case Board and evidence questions are only covered by tests. A short deduction (one clue, one evidence question) would show them on a device, but it waits for the `clue` and `evidence` script syntax: `cerita_tools` compiles Wrong Number from its script and checks the result matches the JSON. The clue notification also covers the VN HUD for its 3 seconds.

## Later features

- **Achievements.** Declared in the story, unlocked by effects or endings, kept in the meta-state, with a screen next to the gallery.
- **Accessibility.** Screen reader labels for the stage, dialogue and controls, a larger text option, a dyslexia-friendly font option, and reduced motion for stage shake and flash (moving letters already stop when the platform asks).
- **Gallery unlock conditions.** Unlock gallery items from conditions, not only from viewing a `MEDIA` item.
