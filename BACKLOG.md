# Backlog

Work that is known but not scheduled. Specs come first: update `specs/` before the code, like the rest of the engine.

## Polish

- **Text tags in choice options.** Choice buttons show tags as written. Render them with `TaggedText`, and strip them where plain text is needed (transcript, `playerText`).
- **Escape tags in player input.** A typed name like `{b}` is interpolated into lines and then styled. Escape `{` in values that come from `INPUT`.
- **Pause auto mode while the UI is hidden.** Auto keeps advancing behind HIDE.
- **Crossfade music.** Track changes fade out, then in, because a second music player would take Android audio focus from the first. A crossfade needs a player setup that shares focus.
- **Rollback in chat and call scenes.** Rollback stops at chat and call threads, which move on by themselves. It would need their pacing to pause and resume.
- **Flexible HUD label.** A very long chapter name can overflow the VN HUD row.
- **Device check.** Animations, fades, volumes, the mouse wheel rollback and story hot reload have only been tested in widget tests and renders. Run them on a device and a desktop.

## Later features

- **Translations.** Per-language story text (separate files or a key table), the player's language in settings, and a UI string table for the built-in screens.
- **Achievements.** Declared in the story, unlocked by effects or endings, kept in the meta-state, with a screen next to the gallery.
- **Accessibility.** Screen reader labels for the stage, dialogue and controls, a larger text option, a dyslexia-friendly font option, and reduced motion for stage shake and flash (moving letters already stop when the platform asks).
- **Gallery unlock conditions.** Unlock gallery items from conditions, not only from viewing a `MEDIA` item.
