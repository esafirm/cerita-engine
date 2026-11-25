# Data & JSON Schemas

This document defines the asset layout and JSON schemas consumed by `EngineLoader`.

## 1. Asset Directory Structure

Configured via `LoaderConfig`:

```text
assets/story/
├── index.json              # Entry-point conversation script
├── profiles.json           # Cast & character profile registry
├── channels.json           # (Optional) Chat thread metadata for Messenger mode
├── clues.json              # (Optional) Clues for the Case Board, see section 8
├── credits.json            # (Optional) People, roles and third-party assets for the Credits screen, see section 9
├── cvn_<id>.json           # Branched conversation scripts (e.g., cvn_qxfOhA.json)
├── bg/                     # Scene background images & event CGs
├── sprites/                # Character expression sprites
├── media/                  # Collectible chat photos, voice notes, and video clips
└── music/                  # Looping BGM tracks and one-shot SFX
```

---

## 2. Character Profiles (`profiles.json`)

Defines all characters in the story, their display metadata, and their ordered expression sprites.

```json
{
  "profiles": [
    {
      "id": "123aaa",
      "name": "Nora",
      "handle": "@nora_w",
      "bio": "Busy chasing deadlines ☕",
      "avatar": "assets/story/sprites/nora_avatar.png",
      "sprites": [
        "nora_open.png",
        "nora_frown.png",
        "nora_smile.png"
      ]
    },
    {
      "id": "123bbb",
      "name": "Miki",
      "handle": "@miki_ghost",
      "bio": "Can anyone read this?",
      "avatar": "assets/story/sprites/miki_avatar.png",
      "sprites": [
        "miki_open.png",
        "miki_frown.png",
        "miki_smile.png"
      ]
    }
  ]
}
```

A profile with sprites can say how tall the character is, so the VN stage sizes the cast against each other
(presentation modes §2.1):

| Field | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `height` | `num` | No | How tall the character is, in any unit the whole cast shares (cm, say). Left out, the stage takes them as tall as the tallest character. |
| `head` | `{"top": num, "chin": num}`, shares from 0 to 1, top above chin | No | Where the head is on the sprites, measured once on one pose: the top of the hair and the bottom of the chin, as shares of the sprite height from its top edge. The stage takes the head as 1/6 of `height` and the top of the hair at `height`, which sets how big the art draws the character and where it stands. Left out, the sprites are taken as head to toe. |

### Profile Reference Format (`<id>:<sprite_index>`)
Dialogue items reference a character and expression using the shorthand `<id>:<sprite_index>` (parsed by `ProfileInfo`):
- `"123aaa:0"` resolves to profile `"123aaa"` (`Nora`) and `sprites[0]` (`"nora_open.png"`).
- `"player"` (or omitted `profile` on outgoing chat items) represents the player character.

### Chat threads (`channels.json`)

Optional. Lists the chat threads a `CHAT` scene's `channel_id` can name.

```json
{
  "channels": [
    { "id": "thread_miki", "name": "Unknown Number", "avatar": "assets/story/sprites/miki_avatar.png",
      "status": "last seen a long time ago", "members": ["123aaa"] },
    { "id": "sekar_tasya", "name": "Tasya", "members": ["456bbb"], "owner": "789ccc" }
  ]
}
```

| Field | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `id` | `String` | Yes | The `channel_id` scenes use. |
| `name` | text | Yes | The thread's name in the chat header. |
| `avatar` | `String` | No | The header avatar. Left out, the contact's avatar is used. |
| `status` | text | No | The header's status line, unless the scene sets its own (§3). |
| `members` | `List<String>` | No | Profile ids. The first one is the thread's contact: its avatar, bio and profile sheet. |
| `owner` | `String` | No | The profile whose phone this thread is on, for a story that reads another character's messages. Messages from the owner sit on the outgoing side like the player's, without avatar or name, and the owner's typing isn't shown. Left out, the thread is the player's. |

---

## 3. Conversation Script (`index.json` & `cvn_<id>.json`)

Each conversation file represents a scene, chat session, or story chapter.

```json
{
  "conversation_id": "cvn_qxfOhN",
  "chapter": "Day 1",
  "title": "Wrong Number",
  "checkpoint": true,
  "scene": {
    "mode": "CHAT",
    "channel_id": "thread_miki",
    "day": 1,
    "time": "23:45",
    "background": "bg_sitting_room.png",
    "music": "sunny.mp3",
    "ambience": "rain_loop.mp3",
    "textbox": "adv"
  },
  "conversations": [
    /* Ordered list of ItemType objects */
  ]
}
```

### `scene` Object Fields

| Field | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `mode` | `"VN"` \| `"CHAT"` \| `"CALL"` | No (defaults to `"VN"`) | Active presentation mode for this conversation. |
| `background` | `String` | No | Background image filename in `bgDir`. |
| `music` | `String` | No | Looping BGM filename in `musicDir`. |
| `ambience` | `String` | No | Looping background sound (rain, crowd, café) in `musicDir`, played under the music. |
| `ring` | `String` | No | `"CALL"` only. The call is incoming: the phone rings with this sound (in `musicDir`, on loop) until the player answers, and the first item waits for the answer (presentation modes §1.2). Left out, the call is already connected. |
| `hangup` | `String` | No | `"CALL"` only. A target (`conv`, `#label` or `conv#label`) the story goes to when the player declines or hangs up (presentation modes §1.2). Left out, the call can't be ended. |
| `stay` | `String` or locale object | No | `"CALL"` only, without `hangup`. What the player's character thinks when they try to end the call, shown as narration over the call buttons. Left out, the engine's own line ("Not now. I need to hear this.") is shown. |
| `textbox` | `"adv"` \| `"nvl"` | No (defaults to `"adv"`) | VN text display: one line in the dialogue box (`adv`), or a full-screen page of lines (`nvl`). |
| `channel_id` | `String` | For `"CHAT"` | Identifier of the messaging thread or contact. |
| `day` | `int` | No | In-game day number (e.g., `1` to `7`). |
| `time` | `String` | No | In-game timestamp displayed in UI headers (e.g., `"23:45"`). Written `"HH:MM"` (24 hours), the chat header shows it the way the player's language writes a time: `"11:45 PM"` in English, `"23.45"` in Indonesian. Any other text is shown as written. |
| `status` | `String`, locale object or `null` | No | Chat only. The status line in the chat header for this scene, in place of the channel's `status` from `channels.json` (e.g., `"online"` during a flashback in a thread whose channel says `"last seen Saturday"`). `null` or `""` shows no status. Left out, the channel's status is shown. |

A conversation **without** a `scene` object continues the current scene and stage. Use it for shared `CALL` subroutines that should not reset the background or characters.

### Story languages (`index.json` only)

`index.json` also declares the languages the story is written in. Both fields are optional and ignored in
`cvn_<id>.json` files. See [section 7](#7-localized-text).

```json
{
  "conversation_id": "cvn_prologue",
  "source_locale": "id",
  "locales": ["id", "en"],
  "conversations": []
}
```

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `source_locale` | `String` | `"id"` | The language the story is written in first. Fallback for text missing in the active language. |
| `locales` | `List<String>` | `[source_locale]` | Every language the story offers. The language switch lists these. |

Locale codes are lowercase ISO 639-1 language codes (`"id"`, `"en"`). A single-language story in another
language than Indonesian declares only `source_locale`, e.g. Wrong Number declares `"en"`.

---

## 4. Conversation Item Types (`conversations`)

Every element in `conversations` shares common optional metadata:
- `id` (`String?`): Optional unique step ID within the conversation. It doubles as a **label** that `target` fields can jump to (see [Targets](#5-targets--labels)).
- `condition` (`String?`): Boolean expression evaluated against `dataMap`. If `false`, the engine skips this item.
- `effects` (`List<Effect>?`): State mutations applied when this item is executed.

### 4.1 `TEXT` — Spoken Dialogue or Chat Message
Displays a character line in the VN dialogue box or a message bubble in Chat mode.

```json
{
  "type": "TEXT",
  "text": "Nice to e-meet you {{NAME}} 🙏",
  "profile": "123aaa:2",
  "position": "center",
  "typing_delay_ms": 1200,
  "sfx": "msg_receive.mp3",
  "voice": "vo_nora_01.mp3"
}
```
- `position` (`"far_left"` \| `"left"` \| `"center"` \| `"right"` \| `"far_right"`): Sprite slot in VN mode. Defaults to the speaker's current slot, or `"center"`.
- `offstage` (`bool`, default `false`): The line is spoken by someone who isn't on the VN stage, like a voice on a recording, a phone or another room. The stage stays as it is: the speaker isn't brought on, an expression change is ignored and `position` is ignored. The dialogue box shows the speaker's name, and the characters on stage are dimmed as listeners. Without it, a speaker who isn't on stage is shown at `position`, or `"center"`.
- `typing_delay_ms` (`int?`): Simulated `"is typing..."` duration in Chat mode before the bubble appears.
- `text` can use [text tags](#6-text-tags), like `NARRATION` text and the prompt of `CHOICE` / `INPUT`.

### 4.2 `NARRATION` — Third-Person Narration or System Event
Renders unattributed narrative text in VN mode or system/status banners in Chat mode (e.g., `"Miki is online"`, `"Day 1 - 11:45 PM"`, `"Missed voice call"`).

```json
{
  "type": "NARRATION",
  "style": "system",
  "text": "Unknown number added you to contacts."
}
```
- `style`: `"narration"` \| `"system"` \| `"timestamp"`.

### 4.3 `MEDIA` — Photos, Voice Notes, Videos & Event CGs
Delivers rich media inside a chat bubble or displays a full-screen CG in VN mode, optionally registering the asset in the player's permanent Gallery.

```json
{
  "type": "MEDIA",
  "media_type": "IMAGE",
  "uri": "photo_luna_cafe.png",
  "title": { "id": "Kafe Luna", "en": "Luna's café" },
  "caption": "Look what I found in her old drawer...",
  "profile": "123bbb:1",
  "unlock_id": "cg_luna_cafe_01",
  "typing_delay_ms": 1500
}
```
- `media_type`: `"IMAGE"` \| `"AUDIO"` (voice note) \| `"VIDEO"` \| `"CG"`.
- `unlock_id` (`String?`): Key saved to the global Gallery registry once viewed.
- `title` (`String?`): Display name of the collectible, shown in the Gallery and in the unlock toast. Falls
  back to `caption`, then to a generic label. Never shows `unlock_id`.
- `transcript` (`String?`): Text of a voice note, behind a "Show transcript" toggle.

### 4.4 `CHOICE` — Branching Player Decision
Presents interactive options to the player. Choices can mutate state variables, require conditions to appear/unlock, enforce a countdown timer, and jump to a target conversation.

```json
{
  "type": "CHOICE",
  "text": "How do you reply to the ghost?",
  "variable": "FIRST_REPLY",
  "profile": "123bbb:0",
  "timeout_ms": 10000,
  "default_choice": 1,
  "choices": [
    {
      "text": "Wait, who is Luna? Tell me everything.",
      "value": "curious",
      "effects": [
        { "variable": "miki_trust", "op": "add", "value": 5 }
      ],
      "target": "qxfOhA"
    },
    {
      "text": "Wrong number. Blocking you now.",
      "value": "dismissive",
      "effects": [
        { "variable": "miki_trust", "op": "subtract", "value": 10 }
      ]
    },
    {
      "text": "[Show Luna's Photo] Is this her?",
      "condition": "has_cafe_photo == true",
      "target": "secret_route"
    },
    {
      "text": "Ask about the photo again",
      "once": true,
      "target": "#ask_photo"
    },
    {
      "text": "Wasn't the boat called the Kenanga?",
      "condition": "meta.flag.knows_boat_name && met_harbor_master",
      "memory_marker": true,
      "target": "harbor_lead"
    }
  ]
}
```
- `profile` (`String?`): Who asks. In VN mode this character becomes the speaker, and one already on stage takes the given expression. Unlike a `TEXT` speaker, it is not brought on stage: show it with a `STAGE` `show` or a `TEXT` line first. The `profile` of `INPUT` and `MEDIA` works the same way.
- `once` (`bool`, default `false`): The choice disappears for the rest of the playthrough after it is picked, for "ask everything" hub menus that loop back on themselves. A `CHOICE` left with no visible options is skipped.
- `silent` (`bool`, default `false`): Picking the option sends no reply. Normally the chosen option becomes the player's line: a sent bubble in a chat, and a line in the backlog. Use it for options that are actions, not words (`Close the app`, `Screenshot it, say nothing`), and for options a scripted player line repeats right after. `"silent": true` on the `CHOICE` itself makes every option silent. The option's `value`, `effects` and `target` apply as usual.
- Choices picked in any earlier playthrough are flagged `chosen` so the UI can mark them.
- A choice whose `condition` fails is shown locked, unless the condition reads cross-playthrough memory
  (`meta.ending.*` or `meta.flag.*`). Then it is left out, so past-run rewards don't show up as locks on a first
  run. See engine-and-state §2 *Cross-Playthrough Memory*.
- `memory_marker` (`bool`, default `false`): Marks the option as unlocked by past runs. While the choice is
  available the UI shows a small marker on it (by default a sparkle, restyled or hidden through
  `StorySkin.memoryMarker`). Use it on unlocks the player should notice. It doesn't change when the choice is
  available: that is still up to `condition`.


#### Evidence questions (`"source": "clues"`)
*Backlog CE-06.* A `CHOICE` with `"source": "clues"` asks the player to present one of the clues they have
found (section 8) instead of picking a listed option. The UI opens the Case Board in picker mode. It has no
`choices`: the options are the clues found in this playthrough, in `clues.json` order.

```json
{
  "type": "CHOICE",
  "id": "ask_hendra",
  "source": "clues",
  "text": { "id": "Petunjuk mana yang membantah dia?", "en": "Which clue contradicts him?" },
  "profile": "hendra:1",
  "variable": "presented_hendra",
  "retries": 1,
  "timeout_ms": 20000,
  "responses": [
    {
      "clue": "harbor_log",
      "effects": [{ "variable": "trust_hendra", "op": "subtract", "value": 2 }],
      "target": "#hendra_caught"
    },
    { "clue": "pier_photo", "target": "#hendra_pier" }
  ],
  "retry": { "target": "#hendra_scoffs" },
  "fallback": {
    "effects": [{ "variable": "trust_hendra", "op": "subtract", "value": 5 }],
    "target": "#hendra_leaves"
  },
  "timeout": { "target": "#hendra_leaves" }
}
```

| Field | Type | Description |
| :--- | :--- | :--- |
| `source` | `"clues"` | Makes the `CHOICE` an evidence question. Any other value is an error. Without it, a normal choice. |
| `text`, `profile`, `variable`, `timeout_ms` | | As for a normal `CHOICE`. `variable` receives the presented clue's `id`. |
| `responses` | `List` | One outcome per specific clue: `clue` (a clue `id`), optional `effects` and `target`. At least one. |
| `retries` | `int`, default `0` | How many times a wrong clue lets the player try again before `fallback`. |
| `retry` | outcome | What plays after a wrong clue while retries remain: optional `effects` and `target`. |
| `fallback` | outcome | What plays for a wrong clue once no retries remain: optional `effects` and `target`. |
| `timeout` | outcome | What plays when `timeout_ms` runs out. Defaults to `fallback`. |

An *outcome* is an object with optional `effects` and `target`, like a choice option without text. A missing
`target` continues with the item after the question, except for `retry` (below).

How the presented clue is answered:

1. A clue with an entry in `responses` plays that response. This is final, whether the author wrote it as
   the right answer or as a specific wrong one.
2. Any other clue is a wrong answer. While retries remain, it uses one up and `retry` plays. Its `target`
   should lead back to the question (`"target": "#hendra_scoffs"`, which ends with a `JUMP` to
   `#ask_hendra`). Without a `retry`, or without a `target` in it, the question is asked again right away.
3. A wrong answer with no retries left plays `fallback`. The retries are counted again from zero the next time
   the question is reached.
4. When `timeout_ms` runs out, `timeout` (or `fallback`) plays. It doesn't use up a retry.

A specific response can also lead back to the question, so a reply to one clue lets the player try again
without using a retry. `default_choice`, `once` and `memory_marker` don't apply to evidence questions.

If the player has found no clue at all when an evidence question is reached, it isn't shown: `fallback` plays
straight away. The linter (authoring-tools §1) reports a question that can be reached before any clue with a
response is awarded, so this should never happen in a finished story.

### 4.5 `INPUT` — Free-Text Player Input
Prompts the player to enter custom text (e.g., player name, passcodes, or puzzle answers) and stores it in `dataMap[variable]`.

```json
{
  "type": "INPUT",
  "text": "What is your name?",
  "variable": "NAME",
  "default_value": "Alex"
}
```

A code or a number asks for digits and a length:

```json
{
  "type": "INPUT",
  "text": "Enter the four-digit code.",
  "variable": "PASSCODE",
  "keyboard": "digits",
  "min_length": 4,
  "max_length": 4
}
```

- `default_value` (`String?`): Stored when the player sends an empty answer. The field shows it as a hint.
- `keyboard` (`"text"` \| `"digits"`, default `"text"`): `"digits"` opens the number pad and the field takes only the digits 0 to 9. The answer is stored as text, so `"0530"` keeps its leading zero and conditions compare it as a string (`PASSCODE == '0530'`).
- `min_length` (`int?`): The fewest characters the answer needs. The send button stays disabled until the answer is that long. With `min_length`, an empty answer can't be sent, so `default_value` is only a hint.
- `max_length` (`int?`): The most characters the field takes. Typing stops there.
- The answer is trimmed before these checks and before it is stored.

### 4.6 `BRANCH` — Conditional Router
Silently evaluates state conditions in order and jumps to the first matching `target` conversation (used for routing into different chapters or endings based on accumulated affection/flags).

```json
{
  "type": "BRANCH",
  "branches": [
    { "condition": "miki_trust >= 20 && luna_affection >= 15", "target": "ending_true" },
    { "condition": "miki_trust >= 10", "target": "ending_good" }
  ],
  "fallback_target": "ending_bad_01"
}
```

### 4.7 `WAIT` — Pacing & Real-Time Delay
Pauses progression for a specified duration (either short dramatic pauses or real-time chapter cooldowns with local notification text).

```json
{
  "type": "WAIT",
  "duration_ms": 3000,
  "notification_text": "Miki sent you a new message!"
}
```

### 4.8 `ENDING` — Story Completion Marker
Marks the conclusion of a narrative route, recording the unlocked ending in the global registry and triggering the Ending summary screen.

```json
{
  "type": "ENDING",
  "ending_id": "end_04_ghost_peace",
  "title": "Ending 4: Unsent Apology",
  "category": "GOOD",
  "summary": "You helped Miki deliver his final message to Luna."
}
```
- `category`: `"TRUE"` \| `"GOOD"` \| `"NORMAL"` \| `"BAD"` \| `"SECRET"`.

### 4.9 `JUMP` — Unconditional Jump
Silently continues at `target`. Item `effects` are applied first.

```json
{ "type": "JUMP", "target": "#hub" }
```

### 4.10 `CALL` / `RETURN` — Subroutines
`CALL` jumps to `target` and remembers the item after it. `RETURN` (or running out of items in the called conversation) goes back there. Calls nest. The call stack is saved with the playthrough.

```json
{ "type": "CALL", "target": "shared#phone_rings" }
{ "type": "RETURN" }
```

### 4.11 `SET` — Silent State Change
Applies its `effects` without showing anything.

```json
{
  "type": "SET",
  "effects": [
    { "variable": "coin", "op": "set", "expr": "random(0, 1)" },
    { "variable": "persistent.runs", "op": "add", "value": 1 },
    { "variable": "knows_boat_name", "op": "meta_set" }
  ]
}
```
- `meta_set` remembers a fact across playthroughs, read back as `meta.flag.<name>` (engine-and-state §2).

### 4.12 `STAGE` — Stage Direction (VN)
Runs a list of `actions` on the VN stage at once, then continues by itself once the longest action is done (`wait_ms` overrides that, `0` continues immediately). The dialogue box is hidden meanwhile.

```json
{
  "type": "STAGE",
  "actions": [
    { "action": "background", "image": "bg_rooftop.png", "transition": "fade_black", "duration_ms": 1200 },
    { "action": "show", "profile": "123aaa:2", "position": "left", "transition": "slide_left" },
    { "action": "move", "profile": "123bbb", "position": "far_right", "duration_ms": 600 },
    { "action": "weather", "name": "sakura" },
    { "action": "shake", "intensity": 8, "duration_ms": 400 }
  ]
}
```

| `action` | Fields | Effect |
| :--- | :--- | :--- |
| `show` | `profile` (`<id>:<sprite>`), `position`?, `transition`? | Shows a character, or changes its expression / slot. |
| `hide` | `profile` (`<id>`), `transition`? | Removes a character. |
| `clear` | `transition`? | Removes every character. |
| `move` | `profile` (`<id>`), `position` | Slides a character to another slot. |
| `background` | `image` (null for black), `transition`? | Changes the background without starting a new conversation. |
| `cg` | `image` (null hides it), `unlock_id`?, `title`?, `caption`?, `zoom`?, `focus`?, `transition`? | Holds a full-screen CG (a file in `bg/`) over the stage while the lines after it play, until the next `cg`, a `cg` with a null `image`, or a new conversation with its own `scene`. A new `image` cross-fades over the one shown: a variant of the same moment keeps the camera, so the two line up. A CG shown over none starts at `zoom` (default `1`, at least `1`) towards `focus` (default `"center"`). `unlock_id` adds it to the Gallery like a `MEDIA` CG, and `title` and `caption` (localizable, §7.1) name it there and in the unlock toast. |
| `cg_move` | `zoom`?, `focus`?, `duration_ms` | Eases the camera on the CG to `zoom` and `focus` over `duration_ms`: a slow push-in or a pan. The story doesn't wait for it, so it plays on under the next lines. With a `cg` in the same `STAGE`, the move starts from that `cg`'s framing. |
| `music` | `file` (null stops), `fade_ms`? | Changes the looping BGM. The old track fades out and the new one fades in, over `fade_ms` (default `1000`, `0` cuts). |
| `ambience` | `file` (null stops), `fade_ms`? | Changes the looping background sound, faded like `music`. |
| `sound` | `file` | Plays a one-shot sound effect. Sounds can overlap. |
| `weather` | `name`: `"rain"` \| `"snow"` \| `"sakura"` \| null | Particle layer over the stage. Null clears it. |
| `shake` | `intensity` (px, default `10`) | Shakes the stage. |
| `flash` | `color` (`"#RRGGBB"`, default white) | Flashes the screen. |
| `zoom` | `scale` (default `1`), `focus` (a `position`, default `"center"`) | Zooms the camera. Stays until the next `zoom` or a new background. |
| `textbox` | `style`: `"adv"` \| `"nvl"` | Switches between the dialogue box and the full-screen NVL page. Switching to `nvl` starts a new page. |
| `page` | | Starts a new NVL page: the lines shown so far are cleared. |

Every action takes an optional `duration_ms`. `transition` is one of `"fade"` (default), `"dissolve"`, `"fade_black"` (backgrounds), `"slide_left"`, `"slide_right"`, `"slide_up"`, `"zoom"`, `"wipe_left"`, `"wipe_right"` or `"none"`.

A CG `focus` is `"center"`, `"left"`, `"right"`, `"top"`, `"bottom"`, `"top_left"`, `"top_right"`, `"bottom_left"` or `"bottom_right"`: the part of the image kept in view. The CG covers the screen, cropped like a background, so `focus` alone pans across the part that doesn't fit (a portrait CG on a taller phone, a landscape one anywhere), and `zoom` pushes in towards it. A `MEDIA` CG (§4.3) shows for its own line only.

Characters come on stage through `show` and through a `TEXT` speaker who isn't there yet (§4.1). A `CHOICE`, `INPUT` or `MEDIA` `profile` and an `offstage` line don't add anyone.

The stage (background, characters, CG and its camera, music, ambience, weather, zoom, text box and NVL page) is part of the playthrough and is saved. Starting a conversation whose `scene` has another background or mode resets it to that scene. A CG is taken away by any new `scene`.

---

## 5. Targets & Labels

Every `target` field (`CHOICE`, `BRANCH`, `JUMP`, `CALL`) accepts:

| Form | Meaning |
| :--- | :--- |
| `"day2"` | Start of `cvn_day2.json` (`"index"` is `index.json`). |
| `"#hub"` | The item with `"id": "hub"` in the current conversation. |
| `"day2#hub"` | The item with `"id": "hub"` in `cvn_day2.json`. |

A jump into the middle of a conversation does not unlock its checkpoint.

---

## 6. Text Tags

`TEXT` and `NARRATION` text, the prompt of `CHOICE` and `INPUT`, and the text of choice options can style parts of a line and control how it types out. Tags are applied after `{{variable}}` interpolation. Variable values are inserted as written: tags in them are not applied, so a name typed into an `INPUT` like `{b}` shows as `{b}`.

```json
{
  "type": "TEXT",
  "profile": "123aaa:1",
  "text": "Wait.{w=600} You {i}kept{/i} the photo?{w} {shake}{color=#E05050}Why?!{/color}{/shake}"
}
```

| Tag | Effect |
| :--- | :--- |
| `{b}`…`{/b}` | Bold. |
| `{i}`…`{/i}` | Italic. |
| `{u}`…`{/u}` | Underline. |
| `{s}`…`{/s}` | Strikethrough. |
| `{color=#RRGGBB}`…`{/color}` | Text colour (`#AARRGGBB` also works). |
| `{size=1.4}`…`{/size}` | Text size relative to the dialogue text. |
| `{shake}`…`{/shake}` | Letters tremble. |
| `{wave}`…`{/wave}` | Letters bob up and down. |
| `{speed=2}`…`{/speed}` | Types this part at a multiple of the player's text speed (`0.5` is half as fast). |
| `{w}` | Stops typing until the player taps, then continues the same line. |
| `{w=800}` | Pauses typing for 800 ms. |
| `{nw}` | Moves on as soon as the line is typed out, without a tap. For interrupted lines. |

- Closing tags are optional at the end of the line. Tags can nest.
- A `{` that does not start a known tag is shown as written, so `{draft}` is just text. Write `{{` for a `{` that would otherwise start a tag: `{{b}` shows `{b}`.
- `{w}`, `{w=…}`, `{speed}` and `{nw}` only affect the VN dialogue box and NVL page. Skip mode and rolled-back lines show the whole line at once and ignore them.
- Chat bubbles, the call view, the backlog and choice options show the styles without the pauses. The player's reply in the transcript, and the value a choice without `value` stores, are the option text without its tags.
- Reading time in auto mode counts only the visible characters.

---

## 7. Localized Text

A story can hold every language side by side. Any player-visible text field is either a plain string or an
object of locale code to string:

```json
{
  "type": "TEXT",
  "profile": "raka:0",
  "text": { "id": "Lo di mana sekarang?", "en": "Where are you right now?" },
  "voice": "vo_raka_04.mp3"
}
```

A plain string is the same text in every language, so single-language stories need no changes.

### 7.1 Localizable fields

| Where | Fields |
| :--- | :--- |
| Conversation file | `chapter`, `title`, `scene.status` |
| `TEXT`, `NARRATION` | `text` |
| `MEDIA` | `title`, `caption`, `transcript` |
| `STAGE` | a `cg` action's `title` and `caption` |
| `CHOICE` | `text` (the prompt) and each option's `text` |
| `INPUT` | `text` (the prompt), `default_value` |
| `WAIT` | `notification_text` |
| `ENDING` | `title`, `summary` |
| `profiles.json` | `name`, `bio` |
| `channels.json` | `name`, `status` |
| `clues.json` | each clue's `title`, `description`, `chapter` |

Logic fields never take a locale object: `id`, `condition`, `effects`, `variable`, `target`, `value`,
`profile`, `uri`, `voice`, `sfx`, `music`, `background`, `unlock_id`, `ending_id`, `handle`, `scene.time`, an
`INPUT`'s `keyboard`, `min_length` and `max_length`, and a clue's `id` and `image`.

### 7.2 Fallback

The text shown is the first one present, in this order:

1. The active locale (the player's pick).
2. The story's `source_locale` (section 3, defaults to `"id"`).
3. The first key of the object.

A missing translation never blanks a line or stops the story (PRD CE-01, D2). The story authoring toolkit
(CE-02) reports the gaps before release.

### 7.3 Interpolation and player input

`{{VAR}}` placeholders are filled in each language's text separately, so each translation places the value
where its grammar needs it. Values typed by the player (`INPUT`) are stored and shown as typed in every
language.

A localized `CHOICE` option without a `value` stores its **source-language** text (without tags, §6) in `variable`, so state and
conditions don't depend on the language the player picked. Plain-string options keep storing their text as
before. Give options an explicit `value` when conditions test them.

### 7.4 Voice per language

`voice` on `TEXT` and `uri` on `MEDIA` items of type `AUDIO` name one file. For `name.mp3` the player first
tries `name.<locale>.mp3` (e.g. `vo_raka_04.en.mp3`) in the active locale, then `name.mp3`. A story can ship a
clip per language, or one clip shared by every language. Other media (images, CGs, video, music, SFX) are not
localized.

---

## 8. Clues (`clues.json`)

*Backlog CE-05.* A mystery story declares its clues once, in an optional `clues.json` next to `index.json`.
Scenes then only say that a clue is found. A story without the file has no clues and shows no Case Board.

```json
{
  "show_counts": true,
  "clues": [
    {
      "id": "pier_photo",
      "title": { "id": "Foto dermaga", "en": "Pier photo" },
      "description": {
        "id": "Foto buram dari Tasya. Ada perahu di ujung dermaga.",
        "en": "A blurry photo from Tasya. There's a boat at the end of the pier."
      },
      "image": "clue_pier_photo.png",
      "key": true,
      "chapter": { "id": "Hari 2", "en": "Day 2" }
    },
    { "id": "harbor_log", "title": "Harbor log", "description": "The boat signed out at 21:40.", "chapter": "Day 3" }
  ]
}
```

| Field | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `show_counts` | `bool` | No (default `false`) | Show "3 of 5 found" for each chapter on the board (PRD CE-05 D3). |
| `clues[].id` | `String` | Yes | Unique, `[a-zA-Z0-9_]+`. The clue is found when `clue_<id>` is `true`. |
| `clues[].title` | text | Yes | Name on the board, in the notification, the picker and the presented-clue message. |
| `clues[].description` | text | No | Full text in the clue's detail. |
| `clues[].image` | `String` | No | Image file in `media/`, shown on the board and full screen in the detail. |
| `clues[].key` | `bool` | No (default `false`) | A key clue, marked on the board. |
| `clues[].chapter` | text | No | The day or chapter the board groups the clue under. |

*text* fields are localized text (section 7): a plain string, or one string per language such as
`{ "id": "Foto dermaga", "en": "Pier photo" }`, with the usual fallback (section 7.2).

### 8.1 Finding a clue

A clue is found when the playthrough variable `clue_<id>` becomes `true`. Any effect can award it, on any
item, choice option, `SET` or evidence-question outcome:

```json
{ "variable": "clue_pier_photo", "op": "set", "value": true }
```

Conditions read it like any variable: `"condition": "clue_pier_photo == true"`, or `!clue_pier_photo` for a
clue not found yet.

- Awarding a clue that is already found changes nothing and shows no second notification.
- The board shows the clues whose variable is `true` right now. Setting one back to `false` takes it off the
  board, but stories shouldn't: clues are never lost (PRD CE-05). Gate on another variable instead.
- In a story with a `clues.json`, variable names starting with `clue_` are reserved for clues. The linter
  reports a `clue_<x>` variable when `x` isn't declared.
- Clue variables are ordinary playthrough variables, so New game empties the board, and saves, checkpoints
  and rollback restore it with the rest of the state (engine-and-state §10).

### 8.2 Board order

Clues are grouped by `chapter`. Groups keep the order in which their first clue appears in `clues.json`, and
the board lists them newest first. Inside a group clues keep their file order. Clues without a `chapter`
form one group without a heading, listed last. Write `clues.json` in story order.

---

## 9. Credits (`credits.json`)

*Backlog CE-08.* An optional file next to `index.json` that lists who made the story and every third-party asset it
uses. Without it, the story has no Credits screen.

```json
{
  "sections": [
    {
      "title": { "id": "Cerita", "en": "Story" },
      "people": [
        { "name": "Esa Firman", "role": { "id": "Penulis", "en": "Writer" } },
        { "name": "Dina" }
      ]
    }
  ],
  "assets": [
    {
      "title": { "id": "Pelabuhan malam", "en": "Harbor at night" },
      "author": "Jane Doe",
      "source": "opengameart.org/content/harbor-at-night",
      "license": "CC0 1.0",
      "note": { "id": "Musik bab 3", "en": "Chapter 3 music" }
    }
  ],
  "roll_after": ["end_01_true"]
}
```

| Field | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `sections` | `List` | No | Groups of people, in the order shown: story, art, music, voice, engine, ... |
| `sections[].title` | text | Yes | Section heading. |
| `sections[].people[].name` | text | Yes | A person, team or tool. |
| `sections[].people[].role` | text | No | What they did. |
| `assets` | `List` | No | Third-party assets, shown after the sections. |
| `assets[].title` | text | Yes | The asset's name. |
| `assets[].author` | `String` | Yes | Who made it. |
| `assets[].source` | `String` | Yes | Where it came from, usually a URL. Shown as text, never opened from the game. |
| `assets[].license` | `String` | Yes | The license name, e.g. `CC0 1.0` or `CC BY 4.0`. |
| `assets[].note` | text | No | What the story uses it for. |
| `roll_after` | `List<String>` | No | `ending_id`s after which the credits roll (presentation modes §4). |

"text" fields are localized text ([section 7](#7-localized-text)). Open-source software licenses aren't listed
here: the Credits screen links to the licenses Flutter collects from the app's packages.
