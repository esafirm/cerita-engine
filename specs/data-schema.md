# Data & JSON Schemas

This document defines the asset layout and JSON schemas consumed by `EngineLoader`.

## 1. Asset Directory Structure

Configured via `LoaderConfig`:

```text
assets/story/
├── index.json              # Entry-point conversation script
├── profiles.json           # Cast & character profile registry
├── channels.json           # (Optional) Chat thread metadata for Messenger mode
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

### Profile Reference Format (`<id>:<sprite_index>`)
Dialogue items reference a character and expression using the shorthand `<id>:<sprite_index>` (parsed by `ProfileInfo`):
- `"123aaa:0"` resolves to profile `"123aaa"` (`Nora`) and `sprites[0]` (`"nora_open.png"`).
- `"player"` (or omitted `profile` on outgoing chat items) represents the player character.

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
    "music": "sunny.mp3"
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
| `channel_id` | `String` | For `"CHAT"` | Identifier of the messaging thread or contact. |
| `day` | `int` | No | In-game day number (e.g., `1` to `7`). |
| `time` | `String` | No | In-game timestamp displayed in UI headers (e.g., `"23:45"`). |

---

## 4. Conversation Item Types (`conversations`)

Every element in `conversations` shares common optional metadata:
- `id` (`String?`): Optional unique step ID within the conversation.
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
- `position` (`"left"` \| `"center"` \| `"right"`): Sprite slot in VN mode.
- `typing_delay_ms` (`int?`): Simulated `"is typing..."` duration in Chat mode before the bubble appears.

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
  "caption": "Look what I found in her old drawer...",
  "profile": "123bbb:1",
  "unlock_id": "cg_luna_cafe_01",
  "typing_delay_ms": 1500
}
```
- `media_type`: `"IMAGE"` \| `"AUDIO"` (voice note) \| `"VIDEO"` \| `"CG"`.
- `unlock_id` (`String?`): Key saved to the global Gallery registry once viewed.

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
    }
  ]
}
```

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
