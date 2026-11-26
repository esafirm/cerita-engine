# Backlog

Work that is known but not scheduled. Specs come first: update `specs/` before the code, like the rest of the engine. Why an item was deferred, and the calls made while finishing others, are in [`docs/decisions.md`](docs/decisions.md).

## Polish

- **Crossfade music.** Track changes fade out, then in, because a second music player would take Android audio focus from the first. A crossfade needs a player setup that shares focus.
- **Rollback in chat and call scenes.** Rollback stops at chat and call threads, which move on by themselves. It would need their pacing to pause and resume.
- **Device check.** Rollback, text tags and HIDE were checked on an Android emulator (see the decisions log). Fades and volumes still need a listen on a device, and the mouse wheel rollback and story hot reload a run on a desktop and a device. The Chapters flowchart (layout on a narrow phone, sideways scroll of a wide row), rolling credits and chat typing pace haven't been seen on a device yet.

## Later features

- **Achievements.** Declared in the story, unlocked by effects or endings, kept in the meta-state, with a screen next to the gallery.
- **Accessibility.** Screen reader labels across the remaining screens, a larger text option, and a dyslexia-friendly font option. Reduced motion (moving letters, stage shake, flash tint, still weather, instant camera zooms/pans) and core dialogue/call labels are in.
- **Gallery unlock conditions.** Unlock gallery items from conditions, not only from viewing a `MEDIA` item.
