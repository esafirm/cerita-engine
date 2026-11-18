# Story Authoring Toolkit (`cerita_tools`)

Engineering design for [CE-02](backlog/02-story-authoring-toolkit.md). Authors write a story as `.cerita`
scripts plus a few YAML files. `cerita_tools` compiles them into the JSON the engine reads
([data schema](data-schema.md)), checks them, estimates playtime and exports what the voice and art pipelines
need.

It's the authoring layer on top of the engine's own tools ([authoring tools](authoring-tools.md)): those work on
story JSON, this works on scripts. `cerita_tools lint` runs cerita_core's `StoryLinter` on the compiled story, so
both share one set of story checks (§3.1).

`packages/cerita_tools` is a pure Dart package that depends on `cerita_core`:

```bash
dart run cerita_tools compile <story> [out] [--check]
dart run cerita_tools lint <story> [--release] [--assets <dir>]
dart run cerita_tools stats <story> [--locale <code>] [--wpm <n>] [--json]
dart run cerita_tools tts-manifest <story> [--out <file>]
dart run cerita_tools assets <story> [--assets <dir>] [--json]
```

`<story>` is a story folder (§1). The fixture in `packages/cerita_tools/test/fixtures/wrong_number/` is the
Wrong Number demo written as a script, and compiles to the same JSON as `example/assets/story/`.

---

## 1. Story Folder

```text
my_story/
├── cerita.yaml          # Story settings (required)
├── profiles.yaml        # Cast and expression names (required)
├── channels.yaml        # Chat threads (optional), compiled to channels.json
├── clues.yaml           # Case Board clues (optional), compiled to clues.json
└── **/*.cerita          # Scripts, in any folder layout
```

Scripts are read in path order. A file holds one or more conversations (one per scene or one per chapter, as
the author prefers).

### 1.1 `cerita.yaml`

```yaml
source_locale: id          # The language the story is written in first. Default: id
locales: [id, en]          # Every language the story ships. Default: [source_locale]
out: ../app/assets/story   # Default output folder for `compile`
assets: ../app/assets/story # Folder with bg/, sprites/, media/ and music/, for asset checks
asset_prefix: assets/story/ # Avatars starting with this are paths under `assets`. Default shown
stats:
  wpm: { id: 180, en: 220 } # Reading speed per locale. Default: 200
  choice_seconds: 4         # Time to decide on a choice, on top of reading it. Default: 4
  input_seconds: 8          # Time to type into an INPUT. Default: 8
  media_seconds: 4          # Time spent on a photo, video, voice note or CG. Default: 4
```

Paths are relative to `cerita.yaml`. `source_locale` and `locales` are also written to `index.json` (§2.7).

### 1.2 `profiles.yaml`

Each key is the name the scripts use. Expressions are listed in sprite order, so `expressions` compiles to the
`sprites` list and `nora:smile` compiles to `"123aaa:2"`.

```yaml
nora:
  id: 123aaa                # Engine profile id. Default: the key
  name: Nora                # A plain string, or { id: ..., en: ... }. So is bio
  handle: "@nora_w"         # Always a plain string
  bio: Busy chasing deadlines ☕
  avatar: assets/story/sprites/nora_avatar.png
  height: 165               # How tall, in a unit the whole cast shares. Sizes the sprites against each other
  face: { eyes: 0.13, chin: 0.21 }  # Eye line and chin on the sprites, as shares of their height from the top
  expressions:
    open: nora_open.png       # Index 0, used when a script names no expression
    frown: nora_frown.png
    smile: nora_smile.png
```

A plain string value stays a plain string in every locale. A `{locale: text}` map gives one text per locale.
`player` is built in (the player character) and can't be declared. Keys can't be statement keywords (§2.2).
`height` must be a number above 0. `face` gives `eyes` and `chin` between 0 and 1, the eyes above the chin: measure
them on one sprite, in pixels divided by its height (data schema §2).
The engine schema doesn't change: expression names exist only in the toolkit.

### 1.3 `channels.yaml`

```yaml
thread_miki:
  name: Unknown Number      # A plain string, or { id: ..., en: ... }. So is status
  avatar: assets/story/sprites/miki_avatar.png
  status: last seen a long time ago
  members: [miki]           # Profile keys, compiled to engine ids

sekar_tasya:                # A thread on another character's phone
  name: Tasya
  members: [tasya]
  owner: sekar              # Sekar's messages show as outgoing. A profile key
```

### 1.4 `clues.yaml`

The Case Board's clues (CE-05), compiled to `clues.json` ([data schema §8](data-schema.md#8-clues-cluesjson)). Clues
are declared here once, in story order, and scripts only say where one is found (`clue <id>`, §2.4).

```yaml
show_counts: true           # "3 of 5 found" per chapter on the board. Default: false
clues:
  pier_photo:               # The clue id: letters, digits and _
    title: { id: Foto dermaga, en: Pier photo }  # Required. A plain string, or one per locale
    description: { id: Foto buram dari Tasya., en: A blurry photo from Tasya. }
    image: clue_pier_photo.png  # In media/
    key: true               # A key clue, marked on the board
    chapter: { id: Hari 2, en: Day 2 }  # The board groups clues by it
  harbor_log:
    title: Harbor log
```

---

## 2. The `.cerita` Script

```text
# Day 3 at the pier
@conversation d3_pier chapter="Hari 3" chapter.en="Day 3" checkpoint
@scene VN bg=pier_dusk.webp music=tide.ogg day=3 time=17:40

stage
  show hendra:wary right transition=slide_left
hendra:wary [right] voice=vo_d3_hendra_01.mp3
  id: Kapal itu nggak pernah balik malam itu.
  en: That boat never came back that night.
  delivery: low, staring at the water

choice by=raka:worried timeout=10s label=ask
  id: Apa yang kamu lakukan?
  en: What do you do?
? Tanya soal kapal | Ask about the boat
  +trust_hendra 5
  -> d3_boat
? Tunjukkan foto | Show the photo [if has_pier_photo] [default]
  set asked_photo true
  remember saw_pier_photo
  -> d3_photo
? Tanya lagi | Ask again [once]
  -> #ask
```

### 2.1 Lines

- A line starting at column 0 is a **statement**. An indented line belongs to the statement above it.
- Blank lines and lines starting with `#` (after any indent) are ignored.
- Statement headers are made of words, `key=value` attributes and `[...]` modifiers. Values with spaces are
  quoted: `title="A Quiet Evening"`, with `\"` for a quote inside.
- A `key.<locale>=value` attribute gives that locale's version: `chapter="Hari 3" chapter.en="Day 3"`.
- Every statement header can end with `[if <condition>]` (§2.5), which becomes the item's `condition`.
- `label=<id>` gives an item its step `id`, which targets can jump to (§2.4).
- Durations take `ms` or `s`, and a bare number is milliseconds: `typing=1.9s`, `wait 1500`.
- File names are written with their extension, as they are stored.

### 2.2 Statements

Every engine item ([data schema §4](data-schema.md#4-conversation-item-types-conversations)) has a statement:

| Statement | Compiles to | Attributes and modifiers |
| :--- | :--- | :--- |
| `@conversation <key>` | A conversation file: `index.json` for `index`, else `cvn_<key>.json` | `id=` (`conversation_id`, default `cvn_<key>`), `chapter=`, `title=`, `checkpoint` |
| `@scene <VN\|CHAT\|CALL>` | Its `scene`. Leave it out for a conversation that keeps the current scene, like a shared `CALL` target | `bg=`, `music=`, `ambience=`, `ring=` (`CALL` only: the call rings in with this sound until answered), `hangup=` (`CALL` only: where the story goes when the player hangs up or declines, a target like `->`), `stay=` and `stay.en=` (`CALL` only, without `hangup=`: what the player's character thinks when they try to end it), `textbox=adv\|nvl`, `channel=`, `day=`, `time=`, `status=` (`status=none` hides the chat status) |
| `<speaker>[:<expression>]` | `TEXT` | `[far_left]` `[left]` `[center]` `[right]` `[far_right]`, `[offstage]`, `typing=`, `sfx=`, `voice=` |
| `narration` / `system` / `timestamp` | `NARRATION` (no style / `system` / `timestamp`) | `sfx=` |
| `media <IMAGE\|AUDIO\|VIDEO\|CG> <file>` | `MEDIA` | `by=`, `unlock=`, `typing=`, `sfx=` |
| `choice [<VARIABLE>]` | `CHOICE`, followed by `?` options | `by=`, `timeout=`, `silent` |
| `? <text>` | One choice option | `[if <condition>]`, `[default]`, `[once]`, `[memory_marker]`, `[silent]` |
| `input <VARIABLE>` | `INPUT` | `default=`, `by=`, `keyboard=text\|digits`, `length=`, `min_length=`, `max_length=` |
| `wait <duration>` | `WAIT` | |
| `branch` | `BRANCH`, with routes in its body (§2.4) | |
| `-> <target>` | `JUMP` | |
| `call <target>` | `CALL` | |
| `return` | `RETURN` | |
| `set` | `SET`, with effects in its body (§2.4) | |
| `stage` | `STAGE`, with actions in its body (§2.6) | `wait=` (`wait_ms`) |
| `ending <ending_id> <CATEGORY>` | `ENDING` | |

- `<speaker>` is a `profiles.yaml` key or `player`. Without an expression, the first expression is used.
- `by=` takes a speaker the same way and becomes the item's `profile`.
- `input` takes `keyboard=digits` for the number pad and digits only, and `min_length=` and `max_length=` for the
  answer's length (data schema §4.5). `length=4` is short for both, so a four-digit code is
  `input PASSCODE keyboard=digits length=4`. `keyboard=text` is the default.
- `[offstage]` marks a line spoken by someone who isn't on the VN stage, like a voice on a recording or a phone (`offstage`, data schema §4.1). The stage stays as it is, so the speaker isn't brought on. It doesn't go with a position. Example: `sekar [offstage] voice=vo_tape_01.mp3`.
- A line's speaker comes on stage by itself when it isn't there yet. A `by=` speaker doesn't: use `stage` `show` (§2.6) to bring them on.
- `@conversation` starts a conversation and every statement up to the next `@conversation` belongs to it.
  `@scene` comes right after it.
- An effect line at column 0 (§2.4) is a `SET` of its own. Effect lines that follow each other share one `SET`.
- `[default]` marks the option picked when `timeout=` runs out. `[once]` hides an option for the rest of the
  playthrough once picked. `[memory_marker]` marks an option unlocked by past runs. `[silent]` sends no reply
  when the option is picked (data schema §4.4), and `silent` on the `choice` line does that for every option.
- On a `choice` line `silent` is a keyword, never a variable name. `choice silent` and `choice silent by=nora` are
  silent choices without a variable, and `choice PICK silent` stores the pick in `PICK`. `choice silent silent` is
  an error. A script written before the keyword may use `choice silent` for a variable named `silent`, so `lint`
  reports a `choice silent` without a variable as an error when the story reads `silent` anywhere.
- `voice=` and a voice note's file name one clip, as written. The player looks for `name.<locale>.mp3` first and
  falls back to `name.mp3` (CE-01, data schema §5.4), so a story can ship either.
- `clue <id>` at column 0 is an effect line (§2.4), so it's a `SET` that awards the clue where the scene finds it.

#### Evidence questions

`evidence` (CE-06, [data schema §4.4](data-schema.md#evidence-questions-source-clues)) asks the player to present a
clue. Its `?` lines are a clue id for each specific response, and `[retry]`, `[fallback]` and `[timeout]` for the
outcomes. Each takes effects and a `-> <target>` in its body, but no text: the clue is what the player presents.

```text
evidence PRESENTED by=hendra:wary timeout=20s retries=1 label=ask_hendra
  id: Petunjuk mana yang membantah dia?
  en: Which clue contradicts him?
? harbor_log
  -trust_hendra 2
  -> #hendra_caught
? pier_photo
  -> #hendra_pier
? [retry]
  -> #hendra_scoffs
? [fallback]
  -trust_hendra 5
  -> #hendra_leaves
```

| Statement | Compiles to | Attributes and modifiers |
| :--- | :--- | :--- |
| `evidence [<VARIABLE>]` | `CHOICE` with `"source": "clues"`, followed by `?` lines | `by=`, `timeout=`, `retries=` |
| `? <clue_id>` | One entry of `responses` | |
| `? [retry]` / `? [fallback]` / `? [timeout]` | `retry` / `fallback` / `timeout` | |

An evidence question needs at least one response, and each outcome is written at most once. `[if]`, `[default]`,
`[once]`, `[memory_marker]` and `value` don't apply to its lines.

### 2.3 Text

Text goes in the statement's body, one line per locale:

```text
nora:smile
  en: Nice to e-meet you {{NAME}} 🙏 ...kidding.
  id: Senang kenalan, {{NAME}} 🙏 ...bercanda.
```

- `<locale>: <text>` sets the statement's main text field. `<field> <locale>: <text>` sets another one, e.g.
  `summary en: ...` on an ending.
- Text is written as the engine shows it, [text tags](data-schema.md#6-text-tags) included. `\n` is a line
  break.
- Options can put every locale on the `?` line, separated by `|` in `locales` order: `? Tanya | Ask`. With a
  single locale, `|` is plain text. An option written as a bare `?` takes its text from body lines instead.

| Statement | Main field | Other fields |
| :--- | :--- | :--- |
| speaker line, `narration`, `system`, `timestamp`, `choice`, `?`, `input` | `text` | `tts` (speaker lines) |
| `media` | `caption` (`transcript` for `AUDIO`) | `title`, `caption`, `transcript`, `tts` (`AUDIO`) |
| `wait` | `notification` (`notification_text`) | |
| `ending` | `title` | `summary` |

`tts <locale>:` (spoken-text override) and `delivery:` (how a line should sound, not localized) only go into
the voice manifest (§3.4). They never reach the story JSON.

### 2.4 Effects, Targets and Routes

Effect lines go in the body of any statement except `branch`, which the engine follows without running effects.
They run when the item is reached, or when the option is picked:

| Line | Effect JSON |
| :--- | :--- |
| `+<var> [n]` | `{"variable": var, "op": "add", "value": n}` (n defaults to 1) |
| `-<var> [n]` | `{"variable": var, "op": "subtract", "value": n}` |
| `set <var> <value>` | `{"variable": var, "op": "set", "value": value}`: a number, `true`, `false`, a `"string"` or a bare word |
| `set <var> = <expression>` | `{"variable": var, "op": "set", "expr": expression}`. `+<var> = ...` and `-<var> = ...` work the same way |
| `toggle <var>` | `{"variable": var, "op": "toggle"}` |
| `remember <name>` | `{"variable": name, "op": "meta_set"}`: remembered across playthroughs (CE-03) |
| `clue <id>` | `{"variable": "clue_<id>", "op": "set", "value": true}`: the clue is found (CE-05). `<id>` is declared in `clues.yaml` |

Variable names can be `persistent.<name>` (kept across playthroughs, engine-and-state §2).

Option bodies also take `value <value>` (the value stored in the choice's variable) and `-> <target>`.

A target is `day2`, `#label` (an item in the same conversation) or `day2#label` ([data schema §5](data-schema.md#5-targets--labels)).
A `branch` body lists routes in order, then an optional fallback:

```text
branch
  if knows_passcode == true && luna_affection >= 15 -> ending_secret
  if miki_trust >= 20 -> ending_true
  -> ending_bad
```

### 2.5 Conditions

The engine's expression language ([engine §3](engine-and-state.md#3-condition-evaluator)), passed through as
written, including `meta.ending.<ending_id>` and `meta.flag.<name>` from Cross-playthrough memory (CE-03).
The toolkit doesn't parse conditions itself: cerita_core's linter checks them on the compiled story (§3.1).

### 2.6 Stage Directions

A `stage` body has one action per line: the action, its values, then `key=value`s. Every action takes
`transition=` and `duration=`, and compiles to one entry of `actions` ([data schema §4.12](data-schema.md#412-stage--stage-direction-vn)).

```text
stage wait=0
  background bg_rooftop.png transition=fade_black duration=1.2s
  show nora:smile left transition=slide_left
  move miki far_right duration=600
  music none fade=2s
```

| Line | Action |
| :--- | :--- |
| `show <speaker>[:<expression>] [<position>]` | `show` |
| `hide <speaker>` / `clear` | `hide` / `clear` |
| `move <speaker> <position>` | `move` |
| `background <image>\|none` | `background` (`none` is black) |
| `music <file>\|none` / `ambience <file>\|none` | `music` / `ambience`, with `fade=` (`fade_ms`) |
| `sound <file>` | `sound` |
| `weather rain\|snow\|sakura\|none` | `weather` |
| `shake intensity=<px>` / `flash color=#RRGGBB` | `shake` / `flash` |
| `zoom [<scale>] [focus=<position>]` | `zoom` |
| `textbox adv\|nvl` / `page` | `textbox` / `page` |

Positions are `far_left`, `left`, `center`, `right` and `far_right`. A `stage` body can also hold effect lines.

### 2.7 Locales (CE-01)

A localized field ([data schema §5.1](data-schema.md#51-localizable-fields) on the CE-01 branch) compiles to a
plain string when the story has a single locale, and to an object of locale code to text when it has more:
`{"id": "...", "en": "..."}`, keys in `locales` order. Missing locales are left out, and the engine falls back to
the source locale.

`index.json` gets the story's languages (data schema §3): `source_locale` unless it's the default `id` in a
single-language story, and `locales` when there's more than one.

### 2.8 Output

`compile` writes `index.json`, one `cvn_<key>.json` per other conversation, `profiles.json` and, when
`channels.yaml` and `clues.yaml` exist, `channels.json` and `clues.json`. Keys are written in a fixed order with
two-space indents and a final newline, so compiling an unchanged story twice gives identical files. It never
deletes files and warns about `cvn_*.json` files in the output folder that no conversation produces.

`compile --check` compiles in memory and fails if any output file is missing, different or stale. Generated
files are committed (PRD D4), and CI runs `--check` so they can't drift from the scripts.

`compile` fails without writing anything on an error in `cerita.yaml`, `profiles.yaml` or a script's syntax, or
when a script names a speaker or expression that doesn't exist. Every other problem is the linter's job.

---

## 3. Commands

### 3.1 `lint`

Reports every problem with its script file and line, then a summary, and exits with `1` if there are errors:

```text
story/day3.cerita:14: error: Target 'd3_boot' doesn't exist
story/day3.cerita:9: warning: Missing 'en' text
2 problems (1 error, 1 warning)
```

It checks in two layers and reports both together:

1. **Script checks**, on what only exists in the scripts and YAML files:

   | Check | Example |
   | :--- | :--- |
   | Syntax | An unknown statement, stage action or attribute, a body line outside a statement, an option outside a `choice`, a missing prompt or option text |
   | Unknown speaker or expression | `hendra:smirk` when `smirk` isn't in `profiles.yaml` |
   | Unused cast | A character or expression in `profiles.yaml` that no script uses (warning) |
   | Missing translation | A localized field without one of the `locales` (warning) |
   | Structure | No `index` conversation, two conversations with one key |
   | `silent` read as a variable | A `choice silent` without a variable while the story reads a variable named `silent` (§2.2) |

2. **Story checks**: the story is compiled, and cerita_core's `StoryLinter` runs on the JSON, once per locale
   ([authoring tools §1](authoring-tools.md#1-story-linter-storylinter)). Its errors and warnings keep their
   severity, and each one is reported at the script line it's about: the option, branch route, effect or stage
   action when the issue names one, else the item (the scene line for scene issues, `profiles.yaml` for sprites
   and avatars). A script with errors is compiled without its broken
   statements, so both layers are reported in one run.

- `--release` fails on warnings too (PRD D2), so a release has no missing translations, unused cast or
  engine warnings.
- Asset checks need the `assets` folder (`cerita.yaml` or `--assets`). Without it they are skipped with a
  note, and `--release` reports that as an error. A voice clip or voice note passes when its shared file
  exists, or when every locale has its own `name.<locale>.ext`. cerita_core's linter applies the same rule, so
  `cerita lint` on the compiled folder agrees.
- Clue checks are story checks, since clues have JSON fields: a clue used but not declared is reported at its
  `clue` line or evidence response, a clue declared but never found and a missing clue image at its `clues.yaml`
  entry, and an evidence question no clue can answer at its `evidence` line. A `clue` line or `evidence` question
  in a story without `clues.yaml` is a script error, since the core linter treats `clue_` variables as ordinary
  there.

### 3.2 `stats`

Prints words and estimated minutes per conversation, per chapter, the shortest and longest run to each ending,
and the critical path. `--json` prints the same data as JSON.

```text
Locale en, 200 wpm

Chapters              words   min
Prologue                123   1.4
Day 1                   210   3.8
...

Endings                   shortest      longest
end_01_true (TRUE)        5.2 min       7.9 min   index > day1 > call_miki > day2 > ending_true
...

Critical path: 7.9 min, index > day1 > call_miki > day2 > ending_true
```

Each item's time is its reading time plus the story's own pacing:

| Item | Time |
| :--- | :--- |
| Spoken line, narration | words / wpm, plus `typing_delay_ms` |
| Media | `media_seconds` plus caption or transcript reading time, plus `typing_delay_ms` |
| Choice | Prompt and every option read, plus `choice_seconds` |
| Input | Prompt read, plus `input_seconds` |
| Wait | `duration_ms` |
| Stage | `wait_ms`, or its longest action |
| Call | Every item of the called section, from its target to a `RETURN` or the end of that conversation |
| Ending | Title and summary read |

- Words are counted in `--locale` (default: the source locale), falling back to the source text where a
  translation is missing. `{{VAR}}` counts as one word.
- The **shortest** run to an ending skips every conditional item. The **longest** run shows every conditional
  item and counts each loop once. The **critical path** is the longest of the longest runs. Real runs fall in
  between, which is what the calibration in Last Seen M1 is for (PRD D3).
- Chapter totals add up every item of the chapter's conversations once.

### 3.3 `assets`

Lists every file the story references that isn't in the `assets` folder, grouped by kind, with where it is
first referenced. `--json` prints `{kind: [path, ...]}` with paths relative to the `assets` folder, for the art
and audio pipelines. It always exits with `0`: it's a report, and `lint` is the gate.

| Kind | Folder | Referenced by |
| :--- | :--- | :--- |
| `background` | `bg/` | `@scene bg=`, `stage background` |
| `cg` | `bg/` | `media CG` |
| `sprite` | `sprites/` | `profiles.yaml` expressions |
| `avatar` | `sprites/` or under `asset_prefix` | `profiles.yaml`, `channels.yaml` avatars |
| `image`, `video`, `voice_note` | `media/` | `media IMAGE`, `media VIDEO`, `media AUDIO` |
| `clue` | `media/` | `clues.yaml` images |
| `music`, `ambience` | `music/` | `@scene music=` and `ambience=`, `@scene ring=`, `stage music` and `ambience` |
| `sfx` | `music/` | `sfx=`, `stage sound` |
| `voice` | `music/` | `voice=` |

A voice clip or voice note with neither a shared file nor per-locale files is listed as one
`name.<locale>.ext` per missing locale, the files the voice pipeline produces.

### 3.4 `tts-manifest`

Writes every voiced line as JSON, to stdout or `--out`. The Last Seen voice script
([Last Seen §6.1](last-seen.md#61-voice-gemini-tts-adapted-from-menolakngantor)) renders it. Voiced lines are
speaker lines with `voice=` and `media AUDIO` voice notes.

```json
{
  "lines": [
    {
      "id": "vo_d3_hendra_01",
      "file": "vo_d3_hendra_01.en.mp3",
      "kind": "line",
      "speaker": "hendra",
      "speaker_name": "Hendra",
      "locale": "en",
      "text": "That boat never came back that night.",
      "tts_text": "That boat... never came back that night.",
      "delivery": "low, staring at the water",
      "conversation": "d3_pier",
      "source": "day3/pier.cerita:4"
    }
  ]
}
```

- One entry per voiced line and locale. `id` is the clip name without its extension, and `file` is the
  per-locale file the player looks for first, `name.<locale>.ext` (§2.2).
- `text` has its text tags removed, since they style the line on screen and aren't spoken.
- `kind` is `line` or `voice_note`. A voice note's text is its transcript, and its speaker is its `by=`.
- `tts_text` and `delivery` are left out when the script doesn't set them.
- Warnings go to stderr: a voice note without a speaker, a locale without text, and one clip used for lines with
  different text.

---

## 4. Extension Points

- **New statements**: a statement keyword maps to a parser that builds an item, and the item compiles itself to
  JSON. `evidence` (CE-06) reuses the `choice` parser with its own `?` lines.
- **New checks**: a check that can run on story JSON goes into cerita_core's `StoryLinter`, and `cerita_tools
  lint` picks it up. Only checks on names that exist in the script alone go into the script linter.
