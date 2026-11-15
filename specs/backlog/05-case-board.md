# PRD: Case Board (CE-05)

## 1. Document information

| | |
| :--- | :--- |
| **Status** | Backlog |
| **Author** | Esa Firman |
| **Last updated** | 2026-11-15 |
| **Type** | Lean PRD (product scope only) |
| **Priority** | Must, needed by Last Seen M2 |
| **Related features** | Gallery, in-game backlog, save slots, checkpoints, in-game menu and HUD, Present evidence (CE-06), Cross-playthrough memory (CE-03), Story authoring toolkit (CE-02), skins |

## 2. Executive summary

Players collect clues as the story unfolds (a photo in a chat, a contradiction in an interview, a code on
a locker) and review them on a Case Board, grouped by day, each with a title, description and optional
image. A notification marks each new clue, and key clues are marked for the player.

v1 turns reading a mystery into investigating one. The bet is that a visible, growing collection of
evidence keeps players oriented over a 3-hour, 7-day story and makes deduction scenes (CE-06) fair, since
everything the player is asked about is on the board.

## 3. Problem & opportunity

**Context.** The engine can already track story facts that change what happens, but they're invisible to players.

**The gap.**
- Over seven in-game days, players forget what they've learned. Today the only way back is scrolling the
  in-game backlog, which only holds recent lines.
- Mystery stories have no way to show the player's evidence, so deductions feel like guessing.
- The Gallery shows collected media, but it's cross-run and visual. It isn't a record of what the
  player knows in this case.

**Why now.** Last Seen's core loop is collecting clues across days and then using them in deductions. It needs both this PRD and CE-06.

## 4. Goals & objectives

- **Business:** support investigation and mystery stories, a natural fit for chat-sim plus VN hybrids.
- **Player:** always know what they know, and feel progress as the board fills.
- **Story author:** define a clue once and award it anywhere in the story.
- **Integrating developer:** restyle the board to fit the game's theme (cork board, notebook, case file).

## 5. Success metrics

| Type | Metric |
| :--- | :--- |
| **Primary** | Every Last Seen deduction can be answered from clues on the board at that point (verified by CE-02 checks and playtests) |
| **Primary** | In playtests, players open the board before deduction scenes |
| **Guardrail** | Stories that declare no clues show no Case Board entry anywhere |
| **Guardrail** | The board always matches the loaded save or checkpoint, never another run |

### Counter-metrics
- Board interactivity (arranging, connecting). v1 is for reviewing, not playing with.

## 6. Non-goals

- ❌ Player-arranged pinboards, connecting strings or freeform notes.
- ❌ Combining clues into new clues.
- ❌ Losing clues once found (stories can still gate on other state).
- ❌ Keeping clues across playthroughs. That's what remembered facts in CE-03 are for.

## 7. Key product decisions

| # | Decision | Chosen | Why / alternatives |
| :--- | :--- | :--- | :--- |
| D1 | Clue lifetime | Per playthrough: New game empties the board, and loading a save or checkpoint restores that point's board | Keeping clues across runs (like the Gallery) would let a second run present evidence its story never found, which breaks the logic |
| D2 | Where clue details live | The author declares each clue once (title, description, image, key or not, per language). Scenes only say "found clue X" | Writing clue text at every place it's found means inconsistent descriptions and translations |
| D3 | Hidden clues | The board shows only found clues, with a count per day ("3 of 5 found") only if the author enables it | Always showing locked slots spoils structure, and never showing counts gives completionists nothing |

## 8. Target users

The player is primary. The story author defines clues, and integrating developers restyle the board.

## 9. User stories

**Player**
- As a player, I want a notification when I find a clue, so that I notice something important happened.
- As a player, I want to open the board at any time during play, so that I can review evidence before a decision.
- As a player, I want clues grouped by day with a description and image, so that I remember where each came from.
- As a player, I want key clues marked, so that I know what matters most.
- As a player, I want new clues highlighted until I've viewed them, so that I can see what changed.

**Story author**
- As a story author, I want to declare a clue once with its text in both languages, so that it reads the
  same wherever it's found.
- As a story author, I want to award a clue on any line or choice, so that discovery fits the scene.
- As a story author, I want lines and choices to depend on which clues were found, so that the story reacts
  to the investigation.

**Integrating developer**
- As an integrating developer, I want to restyle the board, so that it fits my game's theme.

## 10. Functional requirements

**MoSCoW:** 10.1 to 10.3 are Must. 10.4 is Should.

### 10.1 Clues (Must)
- A story declares its clues: title, description, optional image, key flag and the day or chapter it
  belongs to, with text per language (CE-01).
- Any line or choice can award a clue. Lines, choices and routing can depend on clues found.
- Awarding a clue that's already found does nothing and shows no second notification.

### 10.2 Board screen (Must)
- Reachable from the in-game menu and the VN HUD. In chat scenes it's reachable from the chat's top bar menu.
- Shows found clues grouped by day, newest day first, with key clues marked.
- Tapping a clue opens its detail with the full description and the image full screen.
- Opening the board pauses the story, and closing it resumes.
- Given a story with no declared clues, then no board entry appears anywhere.

### 10.3 Lifetime (Must)
- Given clues found in a run, when the player starts a new game, then the board is empty.
- Given a save made on Day 3, when it's loaded, then the board shows exactly the clues found up to that save.
- Given a replay from the Day 2 checkpoint, then the board shows the clues found before Day 2 in that run.

### 10.4 Feedback (Should)
- Finding a clue shows a short notification with its title. Tapping it opens the clue.
- Unviewed clues are highlighted on the board, and the menu entry shows a count until they're viewed.
- Optional per-day found counts (D3).

## 11. Key flows

1. In a Day 2 chat, Tasya sends a blurry pier photo. A notification says "Clue found: Pier photo".
2. The player taps the notification and reads the clue detail, then returns to the chat.
3. On Day 3, before talking to Pak Hendra, they open the board from the HUD and review Day 2's clues.
4. They load a Day 1 save. The pier photo is no longer on the board.

## 12. Relations to existing features

| Feature | Today | Relationship |
| :--- | :--- | :--- |
| Gallery | Media collected across runs, viewable any time | Stays separate (D1). A clue can show the same image as a gallery item, and finding it can unlock both |
| In-game backlog | Recent lines | Complement. The backlog is "what was said", the board is "what I know" |
| Save slots and checkpoints | Restore a run's state | The board is part of run state, so it's restored with them |
| Present evidence (CE-06) | Not built yet | Uses the board as its picker |
| Cross-playthrough memory (CE-03) | Not built yet | The way to carry a clue's knowledge to a later run |
| Skins | Restyle engine screens | The board and the clue notification are restylable |
| Story authoring toolkit (CE-02) | Not built yet | Checks clues used but not declared, and declared but never awarded |

## 13. Dependencies & assumptions

- Clue text in two languages depends on CE-01.
- Assumes about 20 to 40 clues per story, so the board doesn't need search or filters.

## 14. Risks & mitigations

| Risk | Mitigation |
| :--- | :--- |
| Too many clue notifications break immersion | Authors award only meaningful clues. Notifications are brief and skippable |
| Players miss a key clue and can't progress | Deductions (CE-06) have authored fallbacks, and key clues on the critical path are hard to miss by design |
| The board spoils future content | Only found clues are shown (D3) |

## 15. Phasing

- **v1:** section 10.
- **v2:** player notes on clues, if playtests ask for it.

## 16. Open questions

- Should finding a clue with an image also unlock it in the Gallery automatically, or only when the author
  says so? Recommendation: only when the author says so. Owner: Esa.

## 17. Glossary

See the [shared glossary](README.md#shared-glossary). Additional terms:

| Term | Meaning |
| :--- | :--- |
| Clue | A piece of evidence the player has found in this playthrough, with title, description and optional image |
| Key clue | A clue the author marks as essential, shown with a marker on the board |
| Case Board | The screen listing the clues found |
| Award | The moment the story gives the player a clue |
