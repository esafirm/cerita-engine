# PRD: Present evidence (CE-06)

## 1. Document information

| | |
| :--- | :--- |
| **Status** | In progress |
| **Author** | Esa Firman |
| **Last updated** | 2026-11-15 |
| **Type** | Lean PRD (product scope only) |
| **Priority** | Must, needed by Last Seen M2 |
| **Related features** | Choices, timed choices, Case Board (CE-05), in-game backlog, chat history, chat media messages, save slots |
| **Engineering design** | [data-schema.md §4.4, Evidence questions](../data-schema.md#evidence-questions-source-clues), [engine-and-state.md §10](../engine-and-state.md#10-clues--evidence), [presentation-modes.md §6.3 and §6.4](../presentation-modes.md#63-picker-mode-evidence-questions), [authoring-tools.md §1.3](../authoring-tools.md#13-clues-awardable-before-an-evidence-question) |

## 2. Executive summary

At deduction moments the story asks a question ("Who was on the boat that night?") and the player answers
by picking a clue from their Case Board instead of choosing from listed options. The story responds to the
clue chosen: the right clue moves the case forward, and other clues lead to whatever the author wrote,
whether a retry, lost trust or a bad ending. In chat scenes the chosen clue is sent as a message.

v1 makes deductions feel like reasoning, not guessing. Normal choices show the answer among two or three
options. Presenting evidence from everything the player has found makes them recall and connect.

## 3. Problem & opportunity

**The gap.**
- Normal choices list every option, so the right answer is often obvious from the wording.
- A choice can be shown only if a clue was found, but that still lists it next to the others. The player
  doesn't reason, they spot the new option.
- Mystery games' signature moment, confronting someone with proof, isn't possible.

**Why now.** Last Seen plans about 8 deduction scenes. The early bad endings depend on failed deductions.

## 4. Goals & objectives

- **Business:** give Cerita a signature interaction for mystery and investigation stories.
- **Player:** deductions that feel earned when right and fair when wrong.
- **Story author:** write one question with a response per clue and a fallback, without listing every clue
  as a choice.

## 5. Success metrics

| Type | Metric |
| :--- | :--- |
| **Primary** | Playtesters answer most deductions correctly on the first try but not all, aiming for 60 to 80% on the critical path |
| **Primary** | Playtesters describe wrong answers as their own mistake, not as unfair |
| **Guardrail** | No deduction can be reached without at least one valid answer on the board (checked by CE-02 and automated playthroughs) |
| **Guardrail** | Normal choices are unchanged |

### Counter-metrics
- Difficulty. v1 doesn't try to make deductions hard, only fair and active.

## 6. Non-goals

- ❌ Presenting several clues at once or combining clues.
- ❌ Presenting character profiles as evidence (v2 candidate).
- ❌ Interrupting a testimony line by line (cross-examination).
- ❌ A hint system.

## 7. Key product decisions

| # | Decision | Chosen | Why / alternatives |
| :--- | :--- | :--- | :--- |
| D1 | What the picker shows | All clues found in this run | Showing only relevant clues gives the answer away, and showing undiscovered ones spoils content |
| D2 | Wrong answers | The author writes the outcome: a general fallback, optional responses for specific wrong clues, and an optional retry limit | A fixed engine rule (always retry, or always fail) can't support both forgiving and harsh deductions. Last Seen uses both |
| D3 | How a presented clue appears | It's recorded in the history like a choice. In chat, it's sent as an outgoing message with its image | Leaving it unrecorded makes the backlog and chat history confusing on replay |

## 8. Target users

The player is primary. The story author writes the deductions.

## 9. User stories

**Player**
- As a player, I want to answer a key question by choosing from my evidence, so that I feel I solved it.
- As a player, I want to read a clue's description before presenting it, so that I don't misclick.
- As a player, I want to see the clue I presented in the backlog or chat, so that I remember what I claimed.
- As a player, I want a timer on some confrontations, so that tense moments feel tense.

**Story author**
- As a story author, I want to write a question, the right clue, responses for chosen wrong clues and a
  fallback for everything else, so that every answer gets a reply.
- As a story author, I want to allow a set number of retries, so that I control how forgiving each deduction is.
- As a story author, I want a presented clue to change trust and other state, so that answers have consequences.

## 10. Functional requirements

**MoSCoW:** 10.1 to 10.3 are Must. 10.4 is Should.

### 10.1 Asking (Must)
- An evidence question shows the prompt, then opens the player's Case Board in picker mode.
- The picker shows all clues found in this run (D1), with details readable before confirming.
- Presenting requires a confirmation step, so the player can't misclick.

### 10.2 Responding (Must)
- The author defines responses for one or more specific clues, each with its own consequences and
  continuation, plus a fallback for any other clue.
- Optional retry limit: after a wrong clue, the story can ask again until retries run out, then take the fallback.
- Given a deduction where clue A is right, when the player presents clue A, then the right-answer path plays.
- Given clue B with no specific response, when presented, then the fallback plays.
- Given one retry, when the player presents two wrong clues, then the retry plays after the first and the
  final fallback after the second.

### 10.3 Recording (Must)
- In VN scenes the presented clue appears in the backlog ("Presented: Pier photo").
- In chat scenes the presented clue is sent as an outgoing message showing its image or title, and stays
  in chat history.
- Saves made after a deduction restore it correctly. Saves can't be made in the middle of picking, as with
  normal choices today.

### 10.4 Timers (Should)
- An evidence question can have a countdown like timed choices. When time runs out, the author's timeout
  outcome plays.

## 11. Key flows

**Happy path (VN)**
1. On Day 3, Pak Hendra says the boat left at dawn. Raka thinks: "That doesn't add up."
2. The prompt "Which clue contradicts him?" opens the board in picker mode.
3. The player opens the "Harbor log" clue, reads it and presents it.
4. Hendra's expression changes and the scene continues on the right path. Trust in Hendra goes down.

**Wrong answer with retry (chat)**
1. Tasya asks "What makes you think Sekar knew?"
2. The player presents the "Pier photo". It's sent as an image in the chat.
3. Tasya replies dismissively (the specific response for that clue), and the question is asked again.
4. The player presents the "Unsent message" and the chat moves on.

**Failed deduction**
1. On Day 5, with no retries left, the player presents the wrong clue against Bima.
2. The fallback plays: Bima leaves, trust collapses, and the route heads to the Wrong Name bad ending.

## 12. Relations to existing features

| Feature | Today | Relationship |
| :--- | :--- | :--- |
| Choices | Pick one of the listed options | Borrowed mental model. Evidence questions are choices whose options are the player's clues. Normal choices are unchanged |
| Timed choices | Countdown with a default | Borrowed for 10.4 |
| Case Board (CE-05) | Not built yet | Used as the picker in picker mode |
| Chat media messages | Photos, voice notes and videos in bubbles | Borrowed. A presented clue is sent like a photo message |
| In-game backlog | Recent lines and choices | Records the presented clue |

## 13. Dependencies & assumptions

- Depends on CE-05: no clues means no evidence questions.
- Assumes deductions happen at authored moments only. Players can't present evidence freely.

## 14. Risks & mitigations

| Risk | Mitigation |
| :--- | :--- |
| A deduction with no valid clue on the board softlocks or forces a fail | A CE-02 check plus automated playthroughs over every route, so the right clue is always findable before the question |
| Large boards make picking tedious late in the game | Clues are grouped by day, and authors keep boards around 20 to 40 clues |
| Harsh failures feel unfair | Retries on most deductions, and harsh ones only at clearly signposted moments |

## 15. Phasing

- **v1:** section 10.
- **v2:** presenting character profiles, and multi-clue answers if a story needs them.

## 16. Open questions

- If the player has zero clues at a deduction (which should be impossible), should the engine skip straight
  to the fallback? Recommendation: yes, and CE-02 checks it never happens. Owner: Esa.

## 17. Glossary

See the [shared glossary](README.md#shared-glossary). Additional terms:

| Term | Meaning |
| :--- | :--- |
| Deduction | A story moment where the player answers by presenting evidence |
| Evidence question | The prompt shown at a deduction |
| Present | Choosing a clue as the answer |
| Picker mode | The Case Board opened to choose a clue rather than to browse |
| Fallback | The outcome for any clue the author didn't write a specific response for |
