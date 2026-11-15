# PRD: Cross-playthrough memory (CE-03)

## 1. Document information

| | |
| :--- | :--- |
| **Status** | Backlog |
| **Author** | Esa Firman |
| **Last updated** | 2026-11-15 |
| **Type** | Lean PRD (product scope only) |
| **Priority** | Must, needed by Last Seen M0 (the true ending depends on it) |
| **Related features** | Endings, Gallery, Chapters and checkpoints, save slots, Reset progress, Story authoring toolkit (CE-02) |

## 2. Executive summary

Stories can remember what happened in earlier playthroughs and react to it: which endings the player has
seen and named facts the author chooses to keep, such as "learned the boat's name on the harbor route". On
the next run that knowledge can unlock new dialogue, new choices or a hidden ending.

v1 exists for Last Seen's true ending. It needs clues from both routes, and no single run visits both
routes. The bet is that replays feel like progress when the story acknowledges what the player already
knows, instead of just rereading with skip on.

## 3. Problem & opportunity

**Context.** The engine already keeps some memory across playthroughs: unlocked gallery items, endings
reached, unlocked checkpoints and lines already seen. Players see it in the Gallery, Endings and Chapters
screens.

**The gap.**
- The story itself can't read that memory. A choice can't say "only if the player has seen the Storm
  ending".
- Everything else the story tracks resets on New game, so it's impossible to carry a discovery into the next run.
- Multi-route mysteries need exactly this: the full truth is assembled across runs.

**Why now.** Last Seen's structure (two routes, a true ending that needs both) can't be built without it.

## 4. Goals & objectives

### Business goals
- Support replay-driven story structures (true endings, secret routes, "new game plus" dialogue) as a
  standard Cerita capability.

### User goals
- **Player:** replays reveal new things, and the story recognizes what they figured out before.
- **Story author:** gate content on past runs without hacks.

## 5. Success metrics

| Type | Metric |
| :--- | :--- |
| **Primary** | Last Seen's true ending is reachable only after both routes have been completed, verified by automated playthroughs |
| **Primary** | In playtests, players on a second run notice dialogue or choices that weren't there before |
| **Guardrail** | First playthroughs are identical whether or not this feature exists. Wrong Number is unchanged |
| **Guardrail** | Reset progress clears this memory completely |

### Counter-metrics
- Keeping memory across devices. That's a separate cloud-save problem.

## 6. Non-goals

- ❌ Syncing memory across devices or reinstalls.
- ❌ A player-facing screen listing remembered facts. Endings and Gallery already show the visible parts.
- ❌ Automatically remembering every story variable across runs.
- ❌ Fourth-wall features such as the story commenting on save scumming.

## 7. Key product decisions

| # | Decision | Chosen | Why / alternatives |
| :--- | :--- | :--- | :--- |
| D1 | What gets remembered | Endings reached, plus facts the author explicitly marks to remember | Remembering every variable would leak per-run state such as trust scores into new games and break balance. Endings alone are too coarse for "learned a clue on route A" |
| D2 | What Reset progress clears | Remembered facts too, along with gallery, endings and checkpoints | Keeping facts after a reset would surprise players who want a truly fresh start |
| D3 | Signalling new content | The author decides per choice whether to mark options unlocked by past runs | Always marking spoils some secrets, and never marking hides the reward from players who don't notice |

## 8. Target users

The player is primary, since they experience the payoff. The story author is the one who sets it up.

## 9. User stories

**Player**
- As a player, I want my second run to show options I couldn't see before, so that replaying feels like
  progress rather than repetition.
- As a player, I want the true ending to need what I learned on every route, so that finishing it feels earned.
- As a player, I want Reset progress to forget everything, so that I can start completely fresh.

**Story author**
- As a story author, I want to mark a fact to remember at any point in a scene, so that discoveries carry
  into future runs.
- As a story author, I want lines, choices and routing to depend on remembered facts and endings reached,
  so that I can gate content on past runs.
- As a story author, I want to optionally mark choices unlocked by past runs, so that players notice the
  reward when I want them to.

## 10. Functional requirements

**MoSCoW:** 10.1 and 10.2 are Must. 10.3 is Should.

### 10.1 Remembering (Must)
- A story can mark a named fact as remembered at any line or choice.
- Remembered facts survive New game, loading any save and replaying from a checkpoint.
- Endings reached are remembered automatically, as today.
- Given a fact remembered in run 1, when the player starts a new game, then the fact is still remembered.
- Given remembered facts, when the player chooses Reset progress, then all are forgotten.

### 10.2 Reacting (Must)
- Any line, choice option or route decision can depend on a remembered fact or on whether a given ending
  has been reached, alone or combined with the current run's state.
- Given the condition "seen the Storm ending and found the boat name in this run", when both are true,
  then the gated choice appears, and otherwise it stays hidden.

### 10.3 Marking new options (Should)
- The author can flag choice options unlocked by past runs, and the engine shows a subtle marker on them.
  Skins can restyle or remove the marker.

## 11. Key flows

1. Run 1: the player takes the Harbor route and learns the boat's name. The story remembers it, and they
   reach the Storm ending.
2. Run 2: they jump to the Day 5 checkpoint and take the Network route. A new line from Tasya references
   the boat, a new marked choice appears, and they reach a Good ending.
3. Run 3: with both routes' facts remembered, the Day 7 router opens the true ending path.

## 12. Relations to existing features

| Feature | Today | Relationship |
| :--- | :--- | :--- |
| Endings screen | Shows endings reached across runs | Complement. The same record becomes readable by the story |
| Gallery | Collectibles kept across runs | Stays separate. Gallery is for the player to view, memory is for the story to use |
| Chapters and checkpoints | Replay from a reached chapter with that run's variables | Complement. Replaying a checkpoint keeps the current memory, not the memory from when the checkpoint was saved |
| Save slots | Save one run's state | Stays separate. Memory isn't part of a slot, so loading an old slot doesn't roll it back |
| Reset progress | Clears gallery, endings, checkpoints | Extended to clear memory too (D2) |
| Story authoring toolkit (CE-02) | Not built yet | Its script supports remembering facts and its checks flag facts read but never remembered |

## 13. Dependencies & assumptions

- Assumes players replay through checkpoints rather than from scratch. CE-07 makes that easier.
- Assumes one player per device install.

## 14. Risks & mitigations

| Risk | Mitigation |
| :--- | :--- |
| Players never find the true ending because the gating is invisible | Use the D3 markers on key unlocks, and have the Endings screen show a locked hint for the true ending |
| A remembered fact makes a later run contradictory | Authors gate remembered-fact dialogue with the current run's state too, and automated playthroughs cover run order |
| Old saves behave unexpectedly with new memory | Memory sits outside saves (section 12), and the automated playthroughs load old-format saves |

## 15. Phasing

- **v1:** 10.1 to 10.3.
- **Later:** cross-device persistence together with cloud saves, if Cerita ever adds them.

## 16. Open questions

- Should the Endings screen show a hint for locked endings, e.g. "Complete both routes"? Recommendation: yes,
  with the author writing the hint text. Owner: Esa. Could be folded into this PRD or the Endings screen
  later.

## 17. Glossary

See the [shared glossary](README.md#shared-glossary). Additional terms:

| Term | Meaning |
| :--- | :--- |
| Memory | Facts that survive across playthroughs on this device |
| Remembered fact | A named discovery the author marks to keep across runs |
| Run state | Everything the story tracks for the current playthrough only, such as trust scores and clues |
| Reset progress | The existing action that clears all cross-run progress |
