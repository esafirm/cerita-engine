# PRD: Story authoring toolkit (CE-02)

## 1. Document information

| | |
| :--- | :--- |
| **Status** | Backlog |
| **Author** | Esa Firman |
| **Last updated** | 2026-11-15 |
| **Type** | Lean PRD (product scope only) |
| **Priority** | Must, needed by Last Seen M0 |
| **Related features** | Story files, character profiles, Bilingual stories (CE-01), Case Board (CE-05), Cross-playthrough memory (CE-03), automated playthroughs, the voice and art pipelines in [Last Seen section 6](../last-seen.md#6-assets) |

## 2. Executive summary

Story authors write a Cerita story in a readable script: scene headers, characters and expressions by name,
both languages of each line side by side, and choices with their consequences right underneath. The
toolkit turns that script into a playable story, checks it for every mistake that would break a
playthrough, and reports how long each route plays. It also exports the voice lines to record and the
images still missing, which drive the voice and art pipelines.

v1 exists so Last Seen (about 50k words per language, 10 endings) can be written and kept correct by a
small team. The bet is that a readable script plus strict checks is what makes a long branching story
manageable. Hand-edited story files are too noisy to read and too easy to break.

## 3. Problem & opportunity

**Context.** Cerita stories are written directly in the engine's data format today. That works for the
15-minute Wrong Number demo, which is about 16 KB of story.

**The gap.**
- The data format is noisy to read. Most of a scene is punctuation and field names, not dialogue.
- Characters and expressions are referenced by number ("expression 2"). A long story can't be written that way.
- Mistakes show up only when a player hits them: a choice pointing to a scene that doesn't exist, a
  missing image, a misspelled condition, an ending nobody can reach.
- There's no way to know how long a story plays without playing every route by hand.
- Voice and art production have no list of what's needed. People find out by reading the whole story.

**Why now.** Last Seen is about 12x the size of Wrong Number and bilingual. Its 3-hour target needs to be
measurable while writing, not discovered at the end.

## 4. Goals & objectives

### Business goals
- Make Cerita viable for full-length stories, not only demos.
- Hit Last Seen's 3-hour first-playthrough target on purpose, with feedback during writing.

### User goals
- **Story author:** write scenes that read like a script, trust that a passing check means the story
  can't break, and see playtime per route as they go.
- **Integrating developer:** get correct, checked story files without hand-editing them.
- **Asset producers (Last Seen team):** get exact lists of voice lines to record and images to create.

## 5. Success metrics

| Type | Metric |
| :--- | :--- |
| **Primary** | Last Seen has zero broken links, unknown references or unreachable endings at every merge |
| **Primary** | The playtime estimate for the Last Seen M1 slice is within ±15% of the measured playtest time |
| **Primary** | Last Seen is written entirely in the script, with zero hand-edits to generated story files |
| **Guardrail** | Generated stories play identically to hand-written ones. Wrong Number can be expressed in the script and plays the same |
| **Guardrail** | Checking and converting all of Last Seen takes under 10 seconds on a laptop, so it can run on every save |

### Counter-metrics (not optimized in v1)
- Approachability for non-technical writers. The v1 audience is comfortable with a text editor and a terminal.
- Converting existing stories into the script. Last Seen is new, and Wrong Number stays as is.

## 6. Non-goals

- ❌ A visual editor or node-graph GUI.
- ❌ Live preview inside the running app (v2 candidate).
- ❌ Generating voices or images. The toolkit exports what's needed, and the external pipelines produce it.
- ❌ Importing from other narrative languages (Ink, Yarn, Ren'Py).
- ❌ Translation help beyond reporting what's missing.

## 7. Key product decisions

| # | Decision | Chosen | Why / alternatives |
| :--- | :--- | :--- | :--- |
| D1 | How authors write | A Cerita-specific readable script | Hand-editing the data format with a checker is less to build but stays painful at 50k words. Adopting Ink or Yarn gives a mature syntax but maps poorly onto chat threads, typing pacing, sprite slots and media messages, which are Cerita's core |
| D2 | Strictness | Every check blocks release builds. Missing translations only warn while drafting | Blocking everything always would stop playtesting while translation lags behind. Never blocking would let gaps ship |
| D3 | Playtime estimate | Reading time from word count plus the story's own pacing (typing delays, waits), calibrated against a real playtest | Word count alone underestimates chat-heavy scenes, and playing every route by hand doesn't scale |
| D4 | Generated story files in the repo | Committed, with a check that they match the script | Generating at build time would make the app depend on the toolkit to build. Committed files keep the app buildable on its own |

## 8. Target users

The story author is primary. Asset producers, the people running the Last Seen voice and art pipelines, are
secondary and only use the exports. The integrating developer only consumes the output.

## 9. User stories

**Story author**
- As a story author, I want to write a scene as speaker, expression and line, so that I read dialogue and
  not data.
- As a story author, I want to refer to expressions by name ("worried", "smirk"), so that I don't memorize
  sprite numbers.
- As a story author, I want both languages of a line next to each other, so that translation happens in context.
- As a story author, I want a choice's consequences written directly under the option, so that I can see
  what each answer does.
- As a story author, I want broken references reported with file and line, so that I fix them before anyone plays.
- As a story author, I want to know which endings and scenes can't be reached, so that no content is
  accidentally orphaned.
- As a story author, I want words and estimated minutes per chapter and per route, so that I can keep the
  story on its 3-hour budget.

**Asset producer**
- As an asset producer, I want a list of every voiced line with speaker, language, text and delivery
  note, so that I can generate all voice clips in one batch.
- As an asset producer, I want a list of images and sounds the story uses but that don't exist yet, so
  that I know exactly what to create next.

## 10. Functional requirements

**MoSCoW:** 10.1 to 10.3 are Must. 10.4 is Should. 10.5 is Could.

### 10.1 Readable script (Must)
- Covers everything the engine supports: VN, chat and call scenes, every line type, choices with
  conditions, consequences and timers, text input, routing, waits, endings, checkpoints, clues (CE-05),
  evidence choices (CE-06) and memory flags (CE-03).
- Characters and expressions are referenced by name. The toolkit resolves them from the cast list.
- Each line can carry text in several languages (CE-01).
- One script file per scene or chapter. Files can be organized in folders.

### 10.2 Conversion (Must)
- Converts the script into a story the engine plays, with no hand-editing afterwards.
- Given an unchanged script, when converted twice, then the output is identical, so diffs stay clean.

### 10.3 Checks (Must)
Each problem is reported with file and line:
- Links to scenes that don't exist.
- Unknown characters or expressions.
- Images, sprites, music, sounds or videos that don't exist.
- Missing translations: a warning while drafting, an error in release mode.
- Scenes and endings no route can reach.
- Clues used but not declared, or declared but never found.
- Variables read but never set, which usually means a typo.
- Given a script with any error, when checked in release mode, then the check fails and lists every error,
  not just the first.

### 10.4 Playtime report (Should)
- Shows words and estimated minutes per chapter, per route and for the critical path (the longest
  typical run), plus the shortest and longest runs to each ending.
- The reading speed per language is adjustable, so the estimate can be calibrated from playtests.

### 10.5 Production exports (Could, Must before M1 voice and art)
- Voice line list: every voiced line with id, speaker, language, text, spoken-text override and delivery note.
- Missing asset list: everything the story references that doesn't exist yet, grouped by kind.

## 11. Key flows

**Writing loop**
1. The author writes a new Day 3 scene in the script.
2. They run the check. It reports a choice pointing to a misspelled scene and a missing background, with line numbers.
3. They fix both. The check passes and the playtime report shows Day 3 at 26 minutes against a 28-minute budget.
4. They convert, run the game and play the scene.

**Asset loop**
1. After a writing milestone, the producer exports the missing asset list and the voice line list.
2. They hand the lists to the art and voice pipelines.
3. As files arrive, the missing list shrinks to zero.

## 12. Relations to existing features

| Feature | Today | Relationship |
| :--- | :--- | :--- |
| Story data format | What the engine reads, written by hand today | Complement. The toolkit produces it, and hand-written stories keep working |
| Character profiles | Cast list with numbered sprites | Borrowed mental model. The script names expressions, and the cast list maps names to sprites |
| Automated playthroughs | Headless runs that reach every Wrong Number ending | Complement. Checks catch structural problems, and playthroughs catch logic problems |
| Bilingual stories (CE-01) | Not built yet | The toolkit is CE-01's coverage check |
| Case Board (CE-05), Present evidence (CE-06), Cross-playthrough memory (CE-03) | Not built yet | The script covers them, and the checks verify their references |

## 13. Dependencies & assumptions

- The story format needs to be settled for CE-01, CE-03, CE-05 and CE-06 before the script covers them, so
  the script grows with each feature.
- Assumes authors are comfortable with a text editor and running a command.
- Assumes the Last Seen voice and art pipelines accept a list of lines and assets as input.

## 14. Risks & mitigations

| Risk | Mitigation |
| :--- | :--- |
| The script and the engine drift apart as features land | Every engine feature PRD lists its script coverage, and Wrong Number round-trips through the script as a check |
| The playtime estimate is wrong and the 3h target is missed | Calibrate in M1 against a real playtest (D3) before writing the remaining 45k words |
| The script syntax is awkward and authors fight it | Write the Last Seen prologue in it during M0 and adjust the syntax before Day 1 |

## 15. Phasing

- **v1:** 10.1 to 10.3 in M0, 10.4 and 10.5 by M1.
- **v2:** in-app live preview, editor syntax highlighting.
- **Later, if outside authors adopt Cerita:** an import path from other narrative formats.

## 16. Open questions

- Is the toolkit a separate install, or does it ship with the engine packages? Recommendation: part of the
  engine repo, run as a command. Owner: Esa.
- Should Wrong Number move to the script as the reference example? Recommendation: keep its hand-written
  files and add a script copy as a round-trip check. Owner: Esa.

## 17. Glossary

See the [shared glossary](README.md#shared-glossary). Additional terms:

| Term | Meaning |
| :--- | :--- |
| Script | The readable text format authors write stories in |
| Conversion | Turning the script into the story files the engine plays |
| Check | Verifying a script for errors without playing it |
| Critical path | The longest typical run through the story to an ending. It defines the "3 hour" target |
| Release mode | The strictest check setting, where warnings such as missing translations become errors |
| Delivery note | A direction for how a voiced line should sound. Not spoken |

## 18. References

- Script sketch and command list: [Last Seen section 5](../last-seen.md#5-tooling-packagescerita_tools).
