# PRD: Bilingual stories (CE-01)

## 1. Document information

| | |
| :--- | :--- |
| **Status** | In progress. Design: [data schema 7](../data-schema.md#7-localized-text), [engine 9](../engine-and-state.md#9-localization), [presentation 5](../presentation-modes.md#5-language) |
| **Author** | Esa Firman |
| **Last updated** | 2026-11-15 |
| **Type** | Lean PRD (product scope only) |
| **Priority** | Must, needed by Last Seen M0 |
| **Related features** | Story text, engine menus and HUD, Gallery, Endings, in-game backlog, chat history, save slots, skins, Player settings (CE-04), Story authoring toolkit (CE-02) |

## 2. Executive summary

Players pick Indonesian or English, and the whole game appears in that language: story lines, choices,
chapter titles, ending titles, gallery item names, the engine's own menus and the voice notes. They can
switch at any time without losing progress. Authors write each line in both languages inside one story,
so a branch fixed in one language is fixed in both.

v1 targets Indonesian and English for Last Seen, but nothing limits a story to two languages. The bet is
that one story holding every language beats separate per-language copies: the story structure stays
single, and a missing translation becomes a visible, checkable gap instead of a silent drift.

## 3. Problem & opportunity

**Context.** Cerita is inspired by Indonesian chat-sim games and is built by an Indonesian team. Stories in
this space often want a local and a global audience at once.

**The gap.**
- A story can only be written in one language. Showing a second language means copying every chapter.
- With copies, every branch, condition and ending fix has to be made twice, and the copies drift.
- The engine's own screens are English only: menu items ("Save game", "Gallery", "Endings"), HUD buttons
  ("Auto", "Skip"), toasts and dialogs.
- Gallery unlock toasts show an internal id rather than a readable title.
- Voice notes and calls have one audio clip, so a voiced line can't match the language on screen.

**Why now.** Last Seen is Indonesian first with an English version, about 50k words per language. Doing
that with copied stories isn't workable.

## 4. Goals & objectives

### Business goals
- Make multilingual stories a built-in Cerita capability rather than something each story works around.
- Ship Last Seen in two languages from a single story.

### User goals
- **Player:** read and hear the story in their own language, including every menu, and switch whenever
  they like.
- **Story author:** write each line once per language, side by side, and never maintain two story copies.
- **Integrating developer:** get the engine screens in Indonesian and English for free and add more
  languages without forking.

## 5. Success metrics

Cerita has no in-app analytics, so metrics are measured through the story itself, automated playthroughs and playtests.

| Type | Metric |
| :--- | :--- |
| **Primary** | Every Last Seen line is available in both languages at release (checked by CE-02) |
| **Primary** | After a language switch, the next line and every visible menu use the new language, with no restart |
| **Primary** | Automated playthroughs reach all 10 Last Seen endings in both languages |
| **Guardrail** | Wrong Number, a single-language story, plays exactly as before, and its automated ending runs stay green |
| **Guardrail** | Save files created before this change still load and continue |

### Counter-metrics (not optimized in v1)
- Translator tooling (glossaries, translation memory, review workflow).
- Polish for languages beyond Indonesian and English. They should work, but only these two are tested.

## 6. Non-goals

- ❌ Machine translation, automatic or assisted.
- ❌ Different story content per language (extra scenes or different branches in one language).
- ❌ Right-to-left scripts.
- ❌ Localized artwork. Text baked into images stays as drawn, so authors should avoid it.
- ❌ Translating what the player types (names, passwords). It's shown as typed.
- ❌ Voicing every line. Only lines the author gives voice clips to are voiced (CE-01 just makes those
  clips follow the language).

## 7. Key product decisions

| # | Decision | Chosen | Why / alternatives |
| :--- | :--- | :--- | :--- |
| D1 | Where translations live | Inside the one story, every language side by side per line | Per-language story copies are simple at first but drift on every fix. Separate key-to-text tables suit professional translators but make writing a 50k-word story painful, because the author can't read a scene in one place |
| D2 | A line has no text in the active language | Show the line in the story's source language | A blank or an error breaks the playthrough for a cosmetic gap. Showing the source language keeps the game playable, and CE-02 flags the gap before release |
| D3 | What already-shown text does after a switch | Backlog and chat history re-display in the new language | Leaving history in the old language mixes two languages on one screen. Re-displaying keeps the reading consistent |
| D4 | Language on first launch | The device language if the story supports it, otherwise the story's source language | Always defaulting to the source language makes English players hunt for the setting. Asking on every first launch adds a step most players don't need |
| D5 | Voice clips | Each voiced line can have a clip per language, falling back to one shared clip | One clip per line can't match the text. Requiring every language for every clip blocks stories that only voice one language |

## 8. Target users

See the [shared personas](README.md#shared-personas). The player matters most here. The story author is a
close second, since D1 is mainly an authoring decision.

## 9. User stories

**Player**
- As a player, I want the game in my language from the first screen, so that I never wade through a
  language I read slowly.
- As a player, I want to switch language mid-game, so that I can show a friend or compare the original
  Indonesian.
- As a player, I want voice notes to speak the language I'm reading, so that the audio and the text agree.
- As a player, I want gallery items and endings to have readable names, so that the collection feels like
  part of the game.

**Story author**
- As a story author, I want to write both languages of a line next to each other, so that I can
  translate a scene while its context is in front of me.
- As a story author, I want lines missing a translation to still play, so that I can playtest while
  translation is in progress.
- As a story author, I want my single-language stories to keep working untouched, so that bilingual is
  opt-in.

**Integrating developer**
- As an integrating developer, I want the engine's screens available in Indonesian and English, so that I
  don't translate menus myself.
- As an integrating developer, I want to add another language for the engine's screens, so that I can ship
  a story in a third language.

## 10. Functional requirements

**MoSCoW:** 10.1 to 10.4 are Must. 10.5 is Should. 10.6 is Could.

### 10.1 Story text in multiple languages (Must)
- Every piece of story text a player can see can be written per language: lines, narration, chat
  messages, media captions, choice options, choice and input prompts, chapter and scene titles, ending
  titles and summaries, and wait notifications.
- Text with no language versions behaves exactly as today.
- Player-entered values such as the player's name are inserted unchanged in every language.
- Given a line with Indonesian and English text and English active, when the line appears, then the
  English text is shown.
- Given a line with only Indonesian text and English active, when the line appears, then the Indonesian
  text is shown and the game continues normally.

### 10.2 Engine screens in multiple languages (Must)
- All text the engine shows itself, including menus, HUD buttons, toasts, confirmation dialogs, the Save,
  Load, Chapters, Gallery and Endings screens and the ending summary, is available in Indonesian and English.
- Integrating developers can supply other languages for these screens.
- Skins can show their own text, and skin authors provide its translations.

### 10.3 Switching language (Must)
- Players can change language from the title screen and during play (in Player settings, CE-04, once that
  exists).
- The choice persists across app restarts and playthroughs.
- Given a player mid-chapter, when they switch language, then the current line, all visible menus, the
  in-game backlog and the chat history show in the new language, and progress is unchanged.
- Saves don't depend on language: a game saved in Indonesian loads correctly in English.

### 10.4 Voice per language (Must)
- A voiced line or voice note can have one audio clip per language.
- Given a line with an Indonesian and an English clip and English active, when it plays, then the English
  clip plays.
- Given a line with only one clip, when it plays in any language, then that clip plays.

### 10.5 Readable collectible names (Should)
- Gallery items have display titles (per language) shown in the Gallery and in unlock notifications,
  instead of internal ids.

### 10.6 Language-aware first launch (Could)
- On first launch, the game uses the device language if the story supports it (D4), and players can
  confirm or change it on the title screen.

## 11. Key flows

**First launch**
1. The player installs Last Seen on a phone set to English.
2. The title screen appears in English.
3. They start a new game. Lines, choices and menus are English.

**Switch mid-game**
1. The player is in the middle of a Day 2 chat.
2. They open settings and pick Bahasa Indonesia.
3. They return to the chat. Earlier messages and the next incoming message are in Indonesian.
4. They save. Later, with English active, they load the save and continue in English from the same message.

## 12. Relations to existing features

| Feature | Today | Relationship |
| :--- | :--- | :--- |
| Wrong Number demo | Single-language English story | Stays separate and unchanged. It's the guardrail that single-language stories still work |
| In-game backlog | History of recent lines | Complement. Follows the active language (D3) |
| Chat history | Delivered messages per chat thread | Complement. Follows the active language (D3) |
| Gallery | Collectibles shown by internal id | Extended with readable per-language titles (10.5) |
| Endings screen | Ending titles and summaries | Complement. Shows them in the active language |
| Save slots | Save and load progress | Unaffected by language. Saves are language-independent |
| Skins | Restyle engine screens | Complement. Skins receive the active language and translate their own text |
| Player settings (CE-04) | Not built yet | Hosts the in-game language switch |
| Story authoring toolkit (CE-02) | Not built yet | Reports missing translations before release |

## 13. Dependencies & assumptions

- CE-02 is the release check for translation coverage. Without it, D2 could hide gaps until a player finds them.
- Assumes Indonesian text runs noticeably longer than English in places, so layouts are tested with
  Indonesian.
- Assumes the in-game language switch can sit on the title screen until CE-04 ships.

## 14. Risks & mitigations

| Risk | Mitigation |
| :--- | :--- |
| Missing translations reach players | CE-02 blocks release builds on gaps, and D2 keeps the game playable regardless |
| Longer text overflows dialogue boxes, choice buttons or chat bubbles | Check layouts in the longer language and test on the smallest supported phone |
| Re-displaying history after a switch confuses players mid-scene | It only changes on explicit player action, so playtest the switch in chat and VN scenes |
| Interpolated values read awkwardly in one language | Authors write each language's sentence around the value. Interpolation inserts values but doesn't rewrite grammar |

## 15. Phasing

- **v1 (this PRD):** 10.1 to 10.5, Indonesian and English.
- **v2:** first-launch language confirmation (10.6), more engine languages.
- **Later, only if a story needs it:** per-language story content and localized artwork.

## 16. Open questions

- Should player-facing text that comes from the integrating app (title screen menu entries, Features page)
  use the same language setting? Recommendation: yes, through the same mechanism. Owner: Esa.
- Should the in-game backlog mark lines that fell back to the source language during playtests?
  Recommendation: only in debug builds. Owner: Esa.

## 17. Glossary

See the [shared glossary](README.md#shared-glossary). Additional terms:

| Term | Meaning |
| :--- | :--- |
| Source language | The language a story is written in first. Indonesian for Last Seen. Used as the fallback |
| Active language | The language the player has picked |
| Fallback | Showing source-language text (or a shared voice clip) when the active language has none |
| Engine screens | Text and screens the engine provides, as opposed to story text the author writes |
