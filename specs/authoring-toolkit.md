# Story Authoring Toolkit (`cerita_tools`)

Engineering design for [CE-02](backlog/02-story-authoring-toolkit.md). Authors write a story as `.cerita`
scripts plus a few YAML files. `cerita_tools` compiles them into the JSON the engine reads
([data schema](data-schema.md)), checks them, estimates playtime and exports what the voice and art pipelines
need.

`packages/cerita_tools` is a pure Dart package with no dependency on the engine packages:

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

Paths are relative to `cerita.yaml`.

### 1.2 `profiles.yaml`

Each key is the name the scripts use. Expressions are listed in sprite order, so `expressions` compiles to the
`sprites` list and `nora:smile` compiles to `"123aaa:2"`.

```yaml
nora:
  id: 123aaa                # Engine profile id. Default: the key
  name: Nora
  handle: "@nora_w"
  bio: Busy chasing deadlines ☕   # A plain string, or { id: ..., en: ... }
  avatar: assets/story/sprites/nora_avatar.png
  expressions:
    open: nora_open.png       # Index 0, used when a script names no expression
    frown: nora_frown.png
    smile: nora_smile.png
```

A plain string value stays a plain string in every locale. A `{locale: text}` map gives one text per locale.
`player` is built in (the player character) and can't be declared. Keys can't be statement keywords (§2.2).
The engine schema doesn't change: expression names exist only in the toolkit.

### 1.3 `channels.yaml`

```yaml
thread_miki:
  name: Unknown Number
  avatar: assets/story/sprites/miki_avatar.png
  status: last seen a long time ago
  members: [miki]           # Profile keys, compiled to engine ids
```

---

## 2. The `.cerita` Script

```text
# Day 3 at the pier
@conversation d3_pier chapter="Hari 3" chapter.en="Day 3" checkpoint
@scene VN bg=pier_dusk.webp music=tide.ogg day=3 time=17:40

hendra:wary [right] voice=vo_d3_hendra_01.{locale}.mp3
  id: Kapal itu nggak pernah balik malam itu.
  en: That boat never came back that night.
  delivery: low, staring at the water

choice by=raka:worried timeout=10s
  id: Apa yang kamu lakukan?
  en: What do you do?
? Tanya soal kapal | Ask about the boat
  +trust_hendra 5
  -> d3_boat
? Tunjukkan foto | Show the photo [if has_pier_photo] [default]
  set asked_photo true
  remember saw_pier_photo
  -> d3_photo
```

### 2.1 Lines

- A line starting at column 0 is a **statement**. An indented line belongs to the statement above it.
- Blank lines and lines starting with `#` (after any indent) are ignored.
- Statement headers are made of words, `key=value` attributes and `[...]` modifiers. Values with spaces are
  quoted: `title="A Quiet Evening"`, with `\"` for a quote inside.
- A `key.<locale>=value` attribute gives that locale's version: `chapter="Hari 3" chapter.en="Day 3"`.
- Every statement header can end with `[if <condition>]` (§2.5), which becomes the item's `condition`.
- `label=<id>` gives an item its optional step `id`.
- Durations take `ms` or `s`, and a bare number is milliseconds: `typing=1.9s`, `wait 1500`.
- File names are written with their extension, as they are stored.

### 2.2 Statements

| Statement | Compiles to | Attributes and modifiers |
| :--- | :--- | :--- |
| `@conversation <key>` | A conversation file: `index.json` for `index`, else `cvn_<key>.json` | `id=` (`conversation_id`, default `cvn_<key>`), `chapter=`, `title=`, `checkpoint` |
| `@scene <VN\|CHAT\|CALL>` | Its `scene` | `bg=`, `music=`, `channel=`, `day=`, `time=` |
| `<speaker>[:<expression>]` | `TEXT` | `[left]` `[center]` `[right]`, `typing=`, `sfx=`, `voice=` |
| `narration` / `system` / `timestamp` | `NARRATION` (no style / `system` / `timestamp`) | `sfx=` |
| `media <IMAGE\|AUDIO\|VIDEO\|CG> <file>` | `MEDIA` | `by=`, `unlock=`, `typing=`, `sfx=` |
| `choice [<VARIABLE>]` | `CHOICE`, followed by `?` options | `by=`, `timeout=` |
| `? <text>` | One choice option | `[if <condition>]`, `[default]` |
| `input <VARIABLE>` | `INPUT` | `default=`, `by=` |
| `wait <duration>` | `WAIT` | |
| `branch` | `BRANCH`, with routes in its body | |
| `-> <key>` | `BRANCH` with only a `fallback_target` (an unconditional jump) | |
| `ending <ending_id> <CATEGORY>` | `ENDING` | |

- `<speaker>` is a `profiles.yaml` key or `player`. Without an expression, the first expression is used.
- `by=` takes a speaker the same way and becomes the item's `profile`.
- `@conversation` starts a conversation and every statement up to the next `@conversation` belongs to it.
  `@scene` comes right after it.
- `voice=` and a `media` file can use `{locale}` to name one clip per locale:
  `voice=vo_01.{locale}.mp3` compiles to `{"id": "vo_01.id.mp3", "en": "vo_01.en.mp3"}`. `voice.en=` names one
  locale's clip on top of a shared one.
- `clue` and `evidence` are reserved for the Case Board (CE-05) and Present evidence (CE-06). Using them is an
  error until those features define their syntax.

### 2.3 Text

Text goes in the statement's body, one line per locale:

```text
nora:smile
  en: Nice to e-meet you {{NAME}} 🙏 ...kidding.
  id: Senang kenalan, {{NAME}} 🙏 ...bercanda.
```

- `<locale>: <text>` sets the statement's main text field. `<field> <locale>: <text>` sets another one, e.g.
  `summary en: ...` on an ending.
- `\n` in text is a line break.
- Options can put every locale on the `?` line, separated by `|` in `locales` order: `? Tanya | Ask`. With a
  single locale, `|` is plain text. An option written as a bare `?` takes its text from body lines instead.

| Statement | Main field | Other fields |
| :--- | :--- | :--- |
| speaker line, `narration`, `system`, `timestamp`, `choice`, `?`, `input` | `text` | `tts` (speaker lines) |
| `media` | `caption` (`transcript` for `AUDIO`) | `caption`, `transcript`, `tts` (`AUDIO`) |
| `wait` | `notification` (`notification_text`) | |
| `ending` | `title` | `summary` |

`tts <locale>:` (spoken-text override) and `delivery:` (how a line should sound, not localized) only go into
the voice manifest (§3.4). They never reach the story JSON.

### 2.4 Effects, Targets and Routes

Body lines of any statement except `branch` and `->`. They run when the item is shown, or when the option is
picked:

| Line | Effect JSON |
| :--- | :--- |
| `+<var> [n]` | `{"variable": var, "op": "add", "value": n}` (n defaults to 1) |
| `-<var> [n]` | `{"variable": var, "op": "subtract", "value": n}` |
| `set <var> <value>` | `{"variable": var, "op": "set", "value": value}`: a number, `true`, `false`, a `"string"` or a bare word |
| `toggle <var>` | `{"variable": var, "op": "toggle"}` |
| `remember <name>` | `{"variable": name, "op": "meta_set"}`: remembered across playthroughs (CE-03) |

Option bodies also take `value <value>` (the value stored in the choice's variable) and `-> <key>` (its target).

A `branch` body lists routes in order, then an optional fallback:

```text
branch
  if knows_passcode == true && luna_affection >= 15 -> ending_secret
  if miki_trust >= 20 -> ending_true
  -> ending_bad
```

Effects can't be put on items that never run them: the engine jumps on a `branch` or `->` without executing it.

### 2.5 Conditions

The engine's condition language ([engine §3](engine-and-state.md#3-condition-evaluator)), passed through as
written. Two read-only names come from Cross-playthrough memory (CE-03):

- `meta.ending.<ending_id>`: the player has reached that ending in any playthrough.
- `meta.flag.<name>`: a `remember <name>` ran in any playthrough.

### 2.6 Locales (CE-01)

A localized field compiles to a plain string when the story has a single locale, and to an object of locale
code to text when it has more: `{"id": "...", "en": "..."}`, keys in `locales` order. Missing locales are left
out, and the engine falls back to the source locale.

### 2.7 Output

`compile` writes `index.json`, one `cvn_<key>.json` per other conversation, `profiles.json` and, when
`channels.yaml` exists, `channels.json`. Keys are written in a fixed order with two-space indents and a final
newline, so compiling an unchanged story twice gives identical files. It never deletes files and warns about
`cvn_*.json` files in the output folder that no conversation produces.

`compile --check` compiles in memory and fails if any output file is missing, different or stale. Generated
files are committed (PRD D4), and CI runs `--check` so they can't drift from the scripts.

`compile` fails without writing anything on an error in `cerita.yaml`, `profiles.yaml` or a script's syntax, or
when a script names a speaker or expression that doesn't exist. Every other problem is the linter's job.

---

## 3. Commands

### 3.1 `lint`

Reports every problem with its file and line, then a summary, and exits with `1` if there are errors:

```text
story/day3.cerita:14: error: Target 'd3_boot' doesn't exist
story/day3.cerita:9: warning: Missing 'en' text
2 problems (1 error, 1 warning)
```

Every check is an error, except missing translations, which are warnings while drafting and errors with
`--release` (PRD D2). All problems are reported, not just the first.

| Check | Example |
| :--- | :--- |
| Syntax | An unknown statement, a bad attribute, a body line outside a statement, an option outside a `choice` |
| Missing target | `-> d3_boot`, an option or route to a conversation that doesn't exist |
| Unknown speaker or expression | `hendra:smirk` when `smirk` isn't in `profiles.yaml` |
| Missing asset | A background, sprite, avatar, music, sound, voice clip or media file that isn't in the `assets` folder |
| Missing translation | A localized field without one of the `locales` |
| Unreachable conversation | No route from `index` leads to it |
| Unreachable ending | An `ending` no route reaches, including one after an unconditional jump |
| Story stops | A route reaches the end of a conversation without an ending or jump, so the engine would stop |
| Variable read but never set | A condition or `{{VAR}}` uses a variable that no effect, `choice` or `input` sets |
| Unknown memory | `meta.flag.x` that no `remember x` sets, or `meta.ending.x` for an ending that doesn't exist |
| Bad condition | A condition that doesn't parse, or a dotted name other than `meta.ending.*` and `meta.flag.*` |
| Structure | No `index` conversation, a duplicate conversation key or label, a `choice` without options or prompt, two `[default]` options, a `CHAT` or `CALL` scene without a channel, an unknown channel |

- Asset checks need the `assets` folder (`cerita.yaml` or `--assets`). Without it they are skipped with a
  note, and `--release` reports that as an error.
- Reachability follows every target regardless of conditions, so it finds content no route can ever reach,
  not content the current numbers happen to lock out. Logic errors are the job of automated playthroughs.
- Clue checks (declared but never found, used but not declared) come with CE-05. The linter has a slot for
  them, keyed by the same file and line positions.

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
| `background` | `bg/` | `@scene bg=` |
| `cg` | `bg/` | `media CG` |
| `sprite` | `sprites/` | `profiles.yaml` expressions |
| `avatar` | `sprites/` or under `asset_prefix` | `profiles.yaml`, `channels.yaml` avatars |
| `image`, `video`, `voice_note` | `media/` | `media IMAGE`, `media VIDEO`, `media AUDIO` |
| `music` | `music/` | `@scene music=` |
| `sfx` | `music/` | `sfx=` |
| `voice` | `music/` | `voice=` |

### 3.4 `tts-manifest`

Writes every voiced line as JSON, to stdout or `--out`. The Last Seen voice script
([Last Seen §6.1](last-seen.md#61-voice-gemini-tts-adapted-from-menolakngantor)) renders it. Voiced lines are
speaker lines with `voice=` and `media AUDIO` voice notes.

```json
{
  "lines": [
    {
      "id": "vo_d3_hendra_01.en",
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

- One entry per voiced line and locale. `id` is the clip file name without its extension.
- A line with one shared clip in a multi-locale story gets a single entry in the source locale, since one clip
  can't match two texts.
- `kind` is `line` or `voice_note`. A voice note's text is its transcript, and its speaker is its `by=`.
- `tts_text` and `delivery` are left out when the script doesn't set them.

---

## 4. Extension Points

- **New statements** (clues for CE-05, evidence choices for CE-06): a statement keyword maps to a parser that
  builds an item, and the item compiles itself to JSON. `clue` and `evidence` are reserved keywords today.
- **New checks**: the linter walks the parsed story and the flow graph that `stats` also uses. Declared and used
  names (variables, memory flags, endings) are collected per namespace with their positions, so clues slot in as
  one more namespace.
- **New condition names**: dotted names are resolved by namespace (`meta.ending`, `meta.flag`). A new feature
  adds its namespace to the linter.
