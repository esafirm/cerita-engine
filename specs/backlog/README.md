# Engine backlog

Product requirements for the Cerita Engine capabilities that the [Last Seen](../last-seen.md) sample game
needs. Each PRD describes what the capability does and why. The engineering design for each one goes in
`specs/*.md` once the PRD is approved.

Every capability is generic. Last Seen is the first story that uses it, not the only one.

## Items

| ID | PRD | Priority | Needed by | Status |
| :--- | :--- | :--- | :--- | :--- |
| CE-01 | [Bilingual stories](01-bilingual-stories.md) | Must | M0 | Done |
| CE-02 | [Story authoring toolkit](02-story-authoring-toolkit.md) | Must | M0 | In progress |
| CE-03 | [Cross-playthrough memory](03-cross-playthrough-memory.md) | Must | M0 | Done |
| CE-04 | [Player settings](04-player-settings.md) | Should | M1 | Done |
| CE-05 | [Case Board](05-case-board.md) | Must | M2 | Done |
| CE-06 | [Present evidence](06-present-evidence.md) | Must | M2 | Done |
| CE-07 | [Route flowchart](07-route-flowchart.md) | Should | M3 | Done |
| CE-08 | [Credits screen](08-credits-screen.md) | Should | M5 | Done |

Milestones refer to [Last Seen section 9](../last-seen.md#9-milestones).

**Status flow:** Backlog, then In review, Approved, In progress, Done. A PRD moves to In progress only after
its design notes land in `specs/`.

**Sizing:** CE-01 to CE-07 are lean PRDs. CE-08 is small and low risk, so it is user stories only.

## Shared personas

| Persona | Who they are | What they want |
| :--- | :--- | :--- |
| **Player** | Someone playing a Cerita story on a phone. For Last Seen, Indonesian or English speaking, 13+, used to chat apps and mobile VNs | A story that reads naturally, respects their time and rewards replaying |
| **Story author** | A writer or small team building a story on Cerita. For now that's the Last Seen team. Later, anyone who picks up the engine | To write a long branching story without breaking it, and to know how long it plays |
| **Integrating developer** | A Flutter developer shipping a Cerita story as an app, restyling it through skins | Engine features that work out of the box and can be restyled without forking |

## Shared glossary

| Term | Meaning |
| :--- | :--- |
| Cerita Engine | This project: the story engine, its Flutter runtime and its default UI |
| Story | One game built on Cerita, e.g. Last Seen or the Wrong Number demo |
| Line | One unit of story content: a spoken line, narration, chat message, media message or prompt |
| Choice | A point where the player picks one of several options |
| Chapter | A section of a story, usually a day. Some chapters are checkpoints |
| Checkpoint | A chapter start the player can replay from later, from the Chapters screen |
| Route | A branch of the story that diverges from the shared path |
| Ending | A conclusion of a route, collected on the Endings screen |
| Playthrough | One run of the story from New game (or a checkpoint) to an ending |
| Gallery | The existing screen of collectible photos, CGs, voice notes and videos, kept across playthroughs |
| Backlog (in-game) | The existing in-game history of recent lines. Not this folder |
| Skin | The engine's restyling layer that integrating developers use to change the look |
| Wrong Number | The existing 15-minute demo story in `example/` |
| Last Seen | The full-length sample game these PRDs serve |
