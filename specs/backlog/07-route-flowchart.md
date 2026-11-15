# PRD: Route flowchart (CE-07)

## 1. Document information

| | |
| :--- | :--- |
| **Status** | In progress ([design](../presentation-modes.md#4-meta-game-screens), [route map](../authoring-tools.md#21-route-map-routemap)). Skip that stops at unseen text (10.2) and the "skip unread" setting already ship. The in-app flowchart (10.1, 10.3) remains |
| **Author** | Esa Firman |
| **Last updated** | 2026-11-15 |
| **Type** | Lean PRD (product scope only) |
| **Priority** | Should, needed by Last Seen M3 |
| **Related features** | Chapters screen and checkpoints, HUD Skip, Endings screen, Cross-playthrough memory (CE-03), Player settings (CE-04) |

## 2. Executive summary

The Chapters screen gains a flowchart view of the story: chapters as nodes, branches as lines, endings
at the tips. Reached parts are revealed, and unreached parts show as locked "???" nodes, so players see
where routes split and which they haven't taken. Tapping a reached checkpoint replays from there. Combined
with the existing Skip, which already stops at unseen lines, players can go after the remaining endings
without rereading.

v1 makes Last Seen's 10 endings practical to collect. A first run is about 3 hours. The flowchart and
skip keep each later run to the new content only.

## 3. Problem & opportunity

**Context.** The Chapters screen lists checkpoints as a flat list and lets players replay reached ones. Skip
already fast-forwards lines the player has seen in any run and stops at the first unseen line.

**The gap.**
- A flat list doesn't show branching. Players can't tell where routes split or what's left.
- With two routes and 10 endings, players need to know which checkpoint to replay from to reach something new.

**Why now.** Last Seen is the first Cerita story with real route structure. Wrong Number's list was enough
for four short endings.

## 4. Goals & objectives

- **Business:** make long branching stories replayable, which is what makes ending counts worth producing.
- **Player:** see the story's shape, know what's left, and jump straight to it.

## 5. Success metrics

| Type | Metric |
| :--- | :--- |
| **Primary** | In playtests, players can say which checkpoint leads to an ending they haven't seen |
| **Primary** | A second Last Seen run to a new ending takes under 1 hour with flowchart and skip |
| **Guardrail** | Unreached content never shows titles or ending names |
| **Guardrail** | Stories without branches still get a usable Chapters screen |

### Counter-metrics
- Showing every scene. The flowchart is chapter-level, not line-level.

## 6. Non-goals

- ❌ Jumping to points that aren't checkpoints.
- ❌ Line-level or choice-level graphs.
- ❌ Showing which choice leads where (that's the player's job).
- ❌ Editing or reordering the story from the flowchart.

## 7. Key product decisions

| # | Decision | Chosen | Why / alternatives |
| :--- | :--- | :--- | :--- |
| D1 | Flowchart vs list | Both views on the Chapters screen. Flowchart is the default when the story branches, otherwise the list | Replacing the list hurts linear stories. A separate screen duplicates the Chapters screen |
| D2 | Unreached nodes | Shown as locked "???" nodes in place | Hiding them hides the "what's left" signal that is the point. Showing titles spoils |
| D3 | Skip unseen text | Skip stops at unseen lines (today's behavior stays the default). Skipping unseen text too is a v2 setting | Changing the default would let players skip new content by accident |

## 8. Target users

The player, especially completionists going after every ending.

## 9. User stories

- As a player, I want to see where the story branches, so that I understand what my choices changed.
- As a player, I want unreached routes shown as locked, so that I know there's more to find without spoilers.
- As a player, I want endings shown at the end of each branch, so that I can see which I've reached.
- As a player, I want to replay from any reached checkpoint on the chart, so that I jump straight to a branch point.
- As a player, I want Skip to stop at lines I haven't read, so that I never miss new content while fast-forwarding.

## 10. Functional requirements

**MoSCoW:** 10.1 and 10.2 are Must. 10.3 is Should.

### 10.1 Flowchart view (Must)
- Shows the story's chapters as nodes connected in story order, with branches where routes split and
  endings at the ends.
- It reflects the story's real structure, including routes the player hasn't taken.
- Reached nodes show their title and day. Unreached nodes show "???". Reached endings show their title and
  category, and unreached endings show only a locked marker.
- Tapping a reached checkpoint offers to replay from it, the same as the list does today.
- Given a player who has only taken the Harbor route, then the Network route nodes appear as "???" and
  can't be tapped.

### 10.2 Skip stops at unseen text (Must, already exists)
- Skip fast-forwards lines seen in any run and stops at the first unseen line, as it does today.
- Skip also stops at every choice and input. This is kept and covered by automated playthroughs, since
  new route content depends on it.

### 10.3 View toggle and reachability (Should)
- The Chapters screen switches between flowchart and list (D1).
- Each reached node shows how many endings beyond it are still unreached.

## 11. Key flows

1. The player finishes run 1 with the Storm ending.
2. They open Chapters, which shows the flowchart. Day 5 splits in two, one side revealed, the other "???".
3. They tap the Day 5 checkpoint and replay.
4. They turn on Skip. It stops at the Day 5 choice, which they answer differently.
5. Skip stops again at the first unseen line of the Network route, and they read on.

## 12. Relations to existing features

| Feature | Today | Relationship |
| :--- | :--- | :--- |
| Chapters screen | Flat list of checkpoints, replay reached ones | Extended with the flowchart view (D1). Replay behavior is unchanged |
| HUD Skip | Skips seen lines, stops at the first unseen | Kept and now a stated requirement (10.2) |
| Endings screen | Collection of reached endings | Complement. The flowchart shows where endings sit, the Endings screen shows their details |
| Cross-playthrough memory (CE-03) | Not built yet | Replaying from a checkpoint keeps remembered facts, so the flowchart is how players use them |
| Player settings (CE-04) | Not built yet | Will host the v2 "skip unseen text" toggle |

## 13. Dependencies & assumptions

- Assumes route structure can be determined from the story itself, without the author drawing the chart.
- Assumes stories have up to about 30 chapters, so the chart fits a phone screen with scrolling.

## 14. Risks & mitigations

| Risk | Mitigation |
| :--- | :--- |
| Complex stories make an unreadable chart on a phone | Chapter-level only, vertical scroll, and authors keep checkpoints to major beats |
| Routing that depends on state makes the drawn structure misleading | Draw every possible branch, and only reveal what was reached |

## 15. Phasing

- **v1:** section 10.
- **v2:** a "skip unseen text" setting, and choice markers on the chart once the branch is reached.

## 16. Open questions

- Should the chart show a branch's ending count as "1 of 3 endings found"? Recommendation: yes, in 10.3.
  Owner: Esa.

## 17. Glossary

See the [shared glossary](README.md#shared-glossary). Additional terms:

| Term | Meaning |
| :--- | :--- |
| Flowchart | The chapter-level map of the story's routes |
| Node | One chapter or ending on the flowchart |
| Seen line | A line the player has already shown in any playthrough on this device |
