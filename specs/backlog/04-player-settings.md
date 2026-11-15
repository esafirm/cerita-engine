# PRD: Player settings (CE-04)

## 1. Document information

| | |
| :--- | :--- |
| **Status** | In progress. Mostly shipped by the settings screen on main. Language shipped with CE-01. Chat pacing (D2) remains |
| **Author** | Esa Firman |
| **Last updated** | 2026-11-15 |
| **Type** | Lean PRD (product scope only) |
| **Priority** | Should, needed by Last Seen M1 |
| **Related features** | HUD Auto and Skip, background music and sound, voice clips, Bilingual stories (CE-01), title screen, in-game menu |

## 2. Executive summary

A settings screen, reachable from the title screen and the in-game menu, where players set language, text
speed, auto-advance speed, chat pacing, and music, sound and voice volume. Changes apply immediately and
are kept across sessions and playthroughs.

A 3-hour story is read in many sittings, often in public, sometimes on mute. v1 gives players control over
pace and sound so they can play comfortably, without the story author having to guess one speed for everyone.

## 3. Problem & opportunity

**The gap.**
- Text speed, auto-advance delay and chat typing pace are fixed. Fast readers wait, slow readers rush.
- There's no volume control inside the game. Players can only mute the whole phone, which also mutes voice
  notes they want to hear.
- Language has no in-game switch (CE-01 needs one).

**Why now.** Short demos get away with fixed values. A 3-hour game with voiced notes and two languages
doesn't.

## 4. Goals & objectives

- **Business:** match the baseline players expect from mobile VNs, so Cerita stories don't feel like demos.
- **Player:** read at their own pace and hear only what they want.
- **Integrating developer:** get the screen for free, restylable through skins.

## 5. Success metrics

| Type | Metric |
| :--- | :--- |
| **Primary** | Every setting change takes effect on the next line without leaving the game |
| **Primary** | Settings survive app restart, New game and loading saves |
| **Guardrail** | Default values reproduce today's pacing exactly, so stories feel the same until a player changes something |

### Counter-metrics
- Completeness against PC VNs, which have dozens of options. v1 covers what mobile players actually adjust.

## 6. Non-goals

- ❌ Accessibility font scaling and high-contrast themes (v2 candidate, see Open questions).
- ❌ Graphics quality options.
- ❌ Controller or keyboard remapping.
- ❌ Per-character voice volume.
- ❌ Syncing settings across devices.

## 7. Key product decisions

| # | Decision | Chosen | Why / alternatives |
| :--- | :--- | :--- | :--- |
| D1 | Scope of settings | Shared by all playthroughs and save slots | Per-save settings would make loading a save change your volume unexpectedly |
| D2 | Chat pacing | Players can speed up chat typing delays (down to instant), but never slow them below the author's value | Letting players stretch delays adds nothing. Speeding up respects fast readers, and the author's value stays the slowest pace |
| D3 | Reset | A "Restore defaults" action on the screen | Having no reset leaves players stuck after experimenting |

## 8. Target users

The player. Integrating developers restyle the screen.

## 9. User stories

- As a player, I want to set text speed, so that dialogue appears at my reading pace.
- As a player, I want to set the auto-advance delay, so that hands-free reading matches my pace.
- As a player, I want to speed up chat typing, so that chat scenes don't drag on a replay.
- As a player, I want separate volumes for music, sound effects and voice, so that I can mute music and
  still hear voice notes.
- As a player, I want to switch language here, so that I don't have to return to the title screen.
- As a player, I want to restore defaults, so that I can undo my experiments.
- As an integrating developer, I want the settings screen to follow my skin, so that it matches my game's look.

## 10. Functional requirements

**MoSCoW:** text speed, auto speed, three volumes, language and persistence are Must. Chat pacing and
Restore defaults are Should. Previewing a setting while adjusting is Could.

- Reachable from the title screen and the in-game menu. Opening it mid-scene pauses the story, and closing
  it resumes where it was.
- **Text speed:** from slow to instant. Instant shows the whole line at once.
- **Auto-advance delay:** from short to long.
- **Chat pacing (D2):** from the author's pace to instant.
- **Volumes:** music, sound effects and voice, each from 0 to 100%, applied immediately. Music ducking under
  voice keeps working at any volume.
- **Language:** as defined in CE-01.
- Given the music volume at 0, when a voice note plays, then the voice is heard at the voice volume.
- Given changed settings, when the player starts a new game or loads a save, then the settings are unchanged.
- Given default settings, then pacing and volume match today's behavior (guardrail).
- **Could:** a sample line previews text speed while it's being adjusted.

## 11. Key flows

1. The player opens the in-game menu during a chat scene and taps Settings.
2. They set music to 0 and chat pacing to fast, then close the screen.
3. The chat resumes faster, a voice note arrives and is clearly audible.
4. Next week they open the app, and their settings are still there.

## 12. Relations to existing features

| Feature | Today | Relationship |
| :--- | :--- | :--- |
| HUD Auto and Skip toggles | Turn auto-advance and skip on or off | Complement. The HUD switches modes, and settings tune their speed |
| Music ducking | Lowers music while voice plays | Complement. Applied on top of the player's music volume |
| Title screen | Menu of New game, Load, Chapters, Gallery, Endings | Gains a Settings entry |
| In-game menu | Save, Backlog, Gallery, Endings | Gains a Settings entry |
| Bilingual stories (CE-01) | Not built yet | This screen hosts its in-game language switch |

## 13. Dependencies & assumptions

- The language option depends on CE-01. Until CE-01 ships, the screen ships without it.
- Assumes the default values equal today's fixed values (guardrail).

## 14. Risks & mitigations

| Risk | Mitigation |
| :--- | :--- |
| Instant chat pacing makes chat scenes lose their tension | It's the player's choice. The default stays at the author's pace |
| Settings reached mid-timed-choice give the player extra time | Opening settings pauses the timer, which is the same as pausing the app today. That's acceptable for a single-player story |

## 15. Phasing

- **v1:** everything in section 10.
- **v2:** text size and contrast options, plus a "skip unread text" toggle (see CE-07).

## 16. Open questions

- Should text size be in v1 for readability on small phones? Recommendation: v2, unless M1 playtests flag
  it. Owner: Esa.

## 17. Glossary

See the [shared glossary](README.md#shared-glossary). Additional terms:

| Term | Meaning |
| :--- | :--- |
| Text speed | How fast a VN line types out |
| Auto-advance | Moving to the next line automatically after a delay |
| Chat pacing | How long the "is typing..." indicator shows before a chat message appears |
| Ducking | Lowering music volume while a voice clip plays |
