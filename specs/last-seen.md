# Last Seen: sample game plan

A full-length mystery sample built on Cerita Engine. It ships in `samples/last_seen/`, next to the
15-minute `example/` feature tour, and drives the engine and tooling work it needs in the same PRs.

## 1. Decisions

| Topic | Decision |
| :--- | :--- |
| Scope | Branching narrative + light game systems (trust, clues, deductions, timed choices) |
| Playtime | ~3h first playthrough to any ending. ~5-6h for 100% with checkpoint skip |
| Script size | ~32k words on the critical path, ~50k words total per language |
| Languages | Indonesian (source) and English (translated after each milestone) |
| i18n model | Inline localized fields: any text is a string or `{"id": ..., "en": ...}` |
| Setting | North Jakarta (Pluit, Muara Angke, Kepulauan Seribu ferries). Casual gue/lo |
| Rating | Teen 13+ |
| Protagonist | Fixed: Raka, 22 (he/him), with a stage sprite like the rest of the cast |
| Endings | 10 endings, 2 route splits |
| Authoring | `.cerita` script DSL compiled to engine JSON by a Dart CLI (`cerita_tools`) |
| Art | Codex image generation (the `codex-image.sh` route from menolakngantor): sprites, backgrounds, CGs, chat photos |
| Audio | CC0 music and SFX. Gemini TTS (the `gemini-voice.mjs` route from menolakngantor) for voice notes and calls only |
| ID review | Manual, once, near the end (M5). Not a gate before then |
| Platforms | Android + iOS, store-ready build (no submission). Web build as a CI smoke check |
| Location | `samples/last_seen/` workspace member |

## 2. Story bible

### Premise

Sekar Ayuningtyas, 22, runs a small investigative podcast about North Jakarta's coast. She vanishes
three days after posting a teaser: "Episode 12: who owns the sea." The police treat it as a runaway case.

Raka hasn't spoken to her in a year, since a falling out he never apologized for. Her sister Dinda calls
him because Sekar's last outgoing message, never delivered, was addressed to him. Over seven days Raka
rebuilds Sekar's last week from her phone, her group chats, the harbor and the people who lied to her.

**The truth (true route only):** Sekar found proof that a reclamation developer bribed officials to fake
an environmental permit. Someone close to her leaked that she had it. After a threat, she hid on Pulau
Pari with help from a harbor boatman, leaving clues only Raka would understand. The undelivered message
was the key.

### Cast

| Character | Role | Voice (ID) | Sprite expressions |
| :--- | :--- | :--- | :--- |
| Raka Pradipta, 22 | Protagonist, Sekar's ex-best friend. Sarcastic, avoidant, guilty | gue/lo | neutral, smirk, worried, angry, shocked, sad, determined |
| Sekar Ayuningtyas, 22 | The missing podcaster. Seen in flashbacks, chats, voice notes | gue/lo, aku/kamu with Dinda | neutral, smile, laugh, serious, scared, tired |
| Dinda, 19 | Sekar's sister, first ally. Trust gates family access | gue/lo, aku with family | neutral, smile, crying, angry, hopeful |
| Tasya Wirawan, 23 | Podcast co-host. Hides that she knew about the threat | gue/lo, Jaksel mix | neutral, smile, nervous, defensive, guilty, crying |
| Bima Santoso, 24 | Sekar's boyfriend. The leak, unknowingly | gue/lo | neutral, charming, irritated, panicked, ashamed |
| Pak Hendra, 56 | Muara Angke boatman, hid Sekar | saya, informal | neutral, gruff, wary, kind, worried |
| Ipda Yusuf, 34 | Police officer on the case. Formal but decent | saya/Anda | neutral, polite, stern, conflicted |

Chat-only contacts (avatar only): Ibu Wulan (Sekar's mother), "Didit" Aditya (developer PR, the
antagonist, appears in chat and call), the podcast listener group "Pendengar Ep. 12", and an unknown
number.

### Structure and playtime budget

Budgets are Indonesian words. The compiler's playtime estimator checks them every build (section 5.3).

| Chapter | Mode mix | Content | Words | Est. time |
| :--- | :--- | :--- | ---: | ---: |
| Prologue | VN + CHAT | A year ago: the falling out. Present: Dinda's call | 1.5k | 10m |
| Day 1: Rumah Kosong | VN | Sekar's house, family, the empty room, getting her phone | 4.0k | 25m |
| Day 2: Grup Chat | CHAT | Unlocking her threads, the listener group, first contradictions | 4.5k | 30m |
| Day 3: Dermaga | VN + CALL | Muara Angke, Pak Hendra, first deduction, Didit's first contact. **Early bad end** possible | 4.5k | 28m |
| Day 4: Malam Itu | CALL + CHAT | Reconstructing the night she vanished, Didit's first call | 4.5k | 28m |
| Day 5: Retak | mix | **Route split**: Harbor route (Hendra, physical trail) or Network route (Tasya/Bima, digital trail) | 4.5k x 2 | 28m |
| Day 6: Badai | VN | Route confrontation, storm crossing. **Bad ends** possible | 4.5k x 2 | 28m |
| Day 7: Terakhir Terlihat | mix | Ending router, final deduction | 3.0k | 18m |
| Endings | VN | 10 endings | 0.8k each | 5m |
| **Critical path** | | | **~32k** | **~3h** |
| **Total per language** | | | **~50k** | |

### Endings

| # | Category | Title (EN) | How |
| :--- | :--- | :--- | :--- |
| 1 | TRUE | Undertow | Find Sekar, publish the evidence, reconcile. Needs key clues from both routes (cross-run, section 4.6) |
| 2 | GOOD | Still Water | Find Sekar, evidence lost. She stays hidden |
| 3 | GOOD | Episode 12 | Evidence published through Tasya, Sekar still missing |
| 4 | GOOD | Unsent | Reconcile through her voice notes without finding her |
| 5 | NORMAL | Runaway | Case closed as runaway. Raka goes back to Bandung |
| 6 | NORMAL | Low Tide | Wrong suspect cleared, trail goes cold |
| 7 | BAD | Handed Over | Day 3: give Sekar's phone to Didit |
| 8 | BAD | Wrong Name | Day 5: failed deduction, trust collapses |
| 9 | BAD | The Storm | Day 6: cross to the island unprepared |
| 10 | SECRET | Off the Record | Unlock all voice notes, find the hidden episode |

## 3. Game systems (on engine primitives)

- **Trust**: numeric `trust_dinda`, `trust_tasya`, `trust_bima`, `trust_hendra`, `trust_yusuf`. Hidden. Gates
  choices, route access and ending routing.
- **Clues**: boolean flags `clue_*` described in a new `clues.json`. Found through choices, media and
  INPUT puzzles. Shown in the Case Board (4.3). Target is 24 clues, with 8 marked `key`.
- **Deductions**: about 8 present-evidence scenes (4.4). A wrong pick costs trust or leads to a bad end.
  Some allow one retry.
- **Puzzles**: about 6 INPUT puzzles (phone passcode, locker code, boat registration, podcast RSS
  password). Answers are checked with conditions, and wrong answers branch to hint dialogue.
- **Timed choices**: used sparingly (about 10) at confrontations and the storm, using the existing `timeout_ms`.
- **Cross-run knowledge**: after reaching any route ending, a meta flag unlocks new dialogue on the next run.
  That's how the true ending works without one run seeing both routes.

## 4. Engine and UI work (reusable, in packages/)

Product requirements for each item live in [`specs/backlog/`](backlog/README.md) (CE-01 to CE-08). This
section is the engineering sketch. Each item updates the relevant `specs/*.md` and adds tests in its package.

1. **Localized text** (`cerita_core`): `LocalizedText` is a string or a locale map, with fallback order
   active, then `id`, then the first key. It applies to `text`, `caption`, choice `text`, `summary`,
   ending `title`, chapter/title and notification text. The locale lives in the engine, and
   `cloneWithData` resolves it before interpolation. Plain strings stay valid, so Wrong Number is
   untouched.
2. **Locale-aware audio** (`cerita_core` + `AudioHelper`): `voice` and MEDIA AUDIO `uri` try
   `name.<locale>.mp3` first, then `name.mp3`.
3. **Clues and Case Board** (`cerita_core` + `cerita_flutter` + skin): optional `clues.json` (id, title,
   description, image, `key` flag, chapter). Collected means the flag `clue_<id> == true` in `dataMap`. A
   meta screen groups clues by day, with a skin hook for the board look.
4. **Present-evidence choice** (`cerita_core` + UI): CHOICE with `"source": "clues"`. Options are the
   collected clues, with per-clue `target`/`effects` and a `fallback` for wrong picks. It renders through
   the Case Board in picker mode.
5. **Settings and locale switch** (`cerita_flutter`): language, text speed, auto speed, BGM/SFX/voice
   volume. Persisted next to meta-state, without being part of save slots.
6. **Flowchart and read-skip** (`cerita_flutter`): skip only fast-forwards items in `seenItems` (verify and
   fix the current `skipMode`). A flowchart screen built from checkpoints and visited conversations sits on
   top of the existing chapters screen.
7. **Meta conditions** (`cerita_core`): a `meta.` namespace in the condition evaluator (`meta.ending.<id>`,
   `meta.flag.<id>`) plus a `meta_set` effect op for cross-run flags.
8. **Credits/licenses screen** (`cerita_ui`): reads a `credits.json`, listing CC0 sources, TTS provider
   and art pipeline.

Out of scope: minigame screens, new presentation modes, cloud saves.

## 5. Tooling: `packages/cerita_tools`

A pure Dart CLI, `dart run cerita_tools <command>`.

### 5.1 `.cerita` DSL

One file per conversation and one scene header. Expressions use names, mapped to sprite indexes by
`profiles.yaml`.

```text
@conversation d3_pier chapter="Hari 3" checkpoint
@scene VN bg=pier_dusk music=tide day=3 time=17:40

hendra:wary [right]
  id: Kapal itu nggak pernah balik malam itu.
  en: That boat never came back that night.

raka:worried [left]
  id: Lo yakin, Pak?
  en: You're sure?

? Tanya soal kapal | Ask about the boat
  +trust_hendra 5
  -> d3_boat
? Tunjukkan foto | Show the photo  [if clue_pier_photo]
  set clue_boat_name true
  -> d3_photo
```

### 5.2 Commands

- `compile <src> <out>`: `.cerita` to `cvn_*.json`, `index.json`, `profiles.json`.
- `lint`: dead or missing targets, unknown profiles/expressions/assets, missing `en` lines (warning
  during drafting, error in release mode), unreachable conversations, endings not reachable from
  `index`, unused clues, variables read but never written.
- `stats`: words and estimated time per route, using the active locale's reading speed plus typing/WAIT
  delays. It prints the critical path and the shortest and longest runs to each ending.
- `tts-manifest`: emits every voice note and call line (id, speaker, locale, text, delivery style) as JSON.
  Rendering happens outside the Dart tool (section 6.1).
- `assets`: compares referenced assets with what's on disk and prints the missing list for the art
  pipeline.

## 6. Assets

| Kind | Count | Notes |
| :--- | ---: | :--- |
| Backgrounds | ~30 | Day/dusk/night variants of ~14 locations. Portrait 9:16 like the phone layout (`example/` uses portrait too). PNG until the size budget needs WebP |
| Sprites | ~42 | 7 characters x ~6 expressions, transparent PNG/WebP, consistent framing |
| Avatars | ~11 | Cast + chat-only contacts |
| CGs | ~15 | Key moments, all gallery unlocks |
| Chat photos | ~20 | Clue photos, screenshots, memes |
| Video clips | 3 | Short loops (ferry, storm, podcast recording) |
| BGM | ~10 | CC0 only (e.g. OpenGameArt CC0, freesound CC0). Pixabay is not CC0, so avoid it or record its license |
| SFX | ~25 | CC0 |
| TTS clips | ~50 x 2 | Voice notes and calls only |

- `credits.json` records the source and license of every audio file.
- App size target is under 200MB. If the budget breaks, we compress to WebP/Opus first.
- Placeholders (a silhouette per character, a gradient per place, silent audio) let writing and code move before
  the art lands. `tools/placeholders.sh` makes them from the `assets` missing list. They carry no text labels, since
  the local ffmpeg has no drawtext: the file name and the speaker box say what they are.

### 6.1 Voice: Gemini TTS (adapted from menolakngantor)

Source: `menolakngantor/videos/scripts/gemini-voice.mjs`. A copy adapted for this game goes in
`samples/last_seen/tools/voice.mjs` and reads the `tts-manifest` output.

- Calls `treg call google-ai.voice-gen.gemini-3-8-flash-tts` with the `gemini-3.8-flash-tts` model, so no
  API key lives in this repo.
- Each character gets a prebuilt voice in `samples/last_seen/tools/voices.json` (Puck-style male voices
  for Raka, Bima, Hendra, Yusuf and Didit, Leda-style female voices for Sekar, Dinda and Tasya). The same
  voice is used for both locales, so a character sounds the same in ID and EN.
- The per-line delivery style goes in `speechMetadata.style` and never in the spoken text.
- Kept from the source: `--dry-run` quotes cost (about $0.001-0.002 per take, so ~$0.20-0.40 for all
  ~100 takes), the take file name is the cache key, raw takes are never overwritten, a retake needs
  `--retake` or a new take name, and a changed voice is refused rather than reused.
- Dropped: the Whisper word-timing pass (no captions needed). Leading and trailing silence is trimmed
  with ffmpeg, and output is `vo_<id>.<locale>.mp3`.
- Indonesian TTS spelling tricks from menolakngantor apply (spell out acronyms, `... CapitalWord` for
  pauses). The manifest gets an optional `tts_text` override so the displayed text stays clean.

### 6.2 Images: Codex (adapted from menolakngantor)

Source: `menolakngantor/videos/scripts/codex-image.sh`. A copy goes in
`samples/last_seen/tools/codex-image.sh` (Codex CLI on the ChatGPT login, empty temp dir,
`--ignore-user-config`, one image per run, optional style-reference image).

- `samples/last_seen/art/style-guide.md` holds the palette, framing rules and prompt templates per asset kind.
- `samples/last_seen/art/prompts/<asset>.txt` holds one prompt per asset, kept next to the output as
  `<asset>.prompt.txt` the way the script already does, so any image can be regenerated.
- Flow: one test image per asset kind, then approval, then a reference sheet per character. The batch run
  passes the character's approved reference with `-i` so expressions stay on-model.
- Sprites need transparency. Ask Codex for a flat chroma background and key it out with ImageMagick,
  then check the edges on dark and light backgrounds. This needs to be proven in M1.
- `make art ASSET=<name>` / `make art-missing` drive the script from the `cerita_tools assets` missing list.

## 7. App: `samples/last_seen/`

- A new workspace member in the root `pubspec.yaml`, with its own app id (e.g. `id.twk.lastseen`), icons,
  splash and a title screen from `cerita_ui` with Last Seen branding and a custom skin subclass if needed.
- Story sources go in `samples/last_seen/story/*.cerita`, and the compiled JSON goes to
  `assets/story/`. The compiled JSON is committed so the app builds without the tool, and CI checks it
  is current.
- Makefile targets: `run-last-seen`, `install-last-seen`, `story` (compile + lint + stats), and `check`
  extended to include the sample.

## 8. Testing

- Headless route tests (like `example/test/story_test.dart`) reach all 10 endings with scripted choice
  sequences, in both locales.
- `cerita_tools lint --release` runs in CI, with zero errors and full `en` coverage on release branches.
- Engine features get unit tests in their packages. New screens get widget tests.
- The `stats` output for the critical path is checked against a 2h45m to 3h30m band.

## 9. Milestones

Each milestone is a PR (or a short stack) that builds, passes `make check` and is playable.

| # | Milestone | Contents |
| :--- | :--- | :--- |
| M0 | Foundations | Localized text, locale audio, meta conditions, `cerita_tools` compile/lint/stats, app skeleton with placeholders |
| M1 | Vertical slice | Prologue + Day 1 fully produced in ID + EN with real art, TTS and music. Settings screen. **Check: does real playtime match the estimator?** |
| M2 | Investigation core | Clues, Case Board, present-evidence choice. Days 2-4 + early bad end. Beat plan: [`last-seen-m2.md`](last-seen-m2.md) |
| M3 | Routes | Day 5-6 both routes, flowchart, read-skip fix, bad endings |
| M4 | Endings | Day 7 router, all 10 endings, secret ending, cross-run true ending |
| M5 | Release polish | Manual Indonesian review, full EN pass, credits, icons, size budget, release builds, playtest and pacing fixes |

M1 is the gate. If the slice doesn't feel like 35 minutes of good content, we retune word budgets before
writing the remaining 45k words.

## 10. Risks and open items

- **Character consistency in AI art** across 7 characters and ~42 sprites. Mitigation: lock reference sheets
  in M1 before mass generation.
- **Indonesian voice quality** isn't reviewed until M5. Jaksel code-mixing for Tasya needs a light touch.
  If the review finds a voice problem across a whole character, it means rework across many days, so the
  cast voice table goes in the style guide from M1.
- **Sprite transparency from Codex** (6.2) is the main unknown in the art pipeline. Prove the chroma-key
  step on one sprite before the batch.
- **Gemini voices in Indonesian**: confirm in M1 that the prebuilt voices sound natural for gue/lo lines
  before rendering every take.
- **Reading speed for Indonesian** may differ from the English-based estimate. Calibrate the estimator
  from the M1 playtest.
- **Scope creep from the systems.** The Case Board and evidence choices stay generic. Anything that only
  Last Seen needs goes in its skin subclass, not the packages.
