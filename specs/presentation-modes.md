# Presentation Modes Specification

Cerita Engine separates narrative state from UI rendering. A story can use **Messenger / Chat Mode**, **Visual Novel Stage Mode**, or switch between them when `EngineListener.onNewScene(Scene)` fires.

---

## 1. Messenger / Chat Mode (*Salah Sambung 3* Style)

Activated when `scene.mode == "CHAT"`. Emulates a modern mobile messaging application.

### 1.1 Layout & Components
- **Top App Bar**:
  - Displays the active contact's avatar, `name`, online status or `bio` from `Profile`, and in-game `day` / `time` from `Scene`.
  - Action buttons for **Profile Details**, **Gallery**, and **Chapter/Settings**.
- **Scrollable Message Timeline**:
  - Renders the delivered transcript for the active `channel_id`.
  - **Incoming Bubbles**: Left-aligned with character avatar and name; styled according to character theme.
  - **Outgoing (Player) Bubbles**: Right-aligned; automatically appended when the player selects a `CHOICE` or submits an `INPUT`.
  - **System / Timestamp Dividers**: Centered pills for `NARRATION` items (`"Day 2 — 09:15 AM"`, `"Luna sent a photo"`).
- **Typing Indicator & Pacing**:
  - When the next item is an incoming `TEXT` or `MEDIA` item with `typing_delay_ms`, displays an animated typing bubble (`"Miki is typing..."`) before revealing the message and playing a notification SFX.
- **Rich Media Bubbles (`MEDIA`)**:
  - **Photo (`IMAGE`)**: Inline thumbnail with optional caption; tapping opens a full-screen pinch-to-zoom viewer.
  - **Voice Note (`AUDIO`)**: Inline audio player bubble with play/pause button, waveform/progress bar, duration, and optional transcript toggle.
  - **Video (`VIDEO`)**: Inline preview with play overlay.
- **Bottom Composer / Interaction Tray**:
  - **Normal Progression**: Tap anywhere or tap the bottom "Continue" prompt to advance incoming messages.
  - **Choice Selection (`CHOICE`)**: Expands a tray of selectable reply cards at the bottom of the chat (with an optional countdown bar if `timeout_ms` is set).
  - **Text Input (`INPUT`)**: Activates the message text field and Send button.

---

## 2. Visual Novel (VN) Stage Mode

Activated when `scene.mode == "VN"` (default). Evolves `SimpleConversation`, `Poi`, and `DialogueBox`.

### 2.1 Layout & Components
- **Background Layer (`Poi`)**:
  - Full-screen scene background (`scene.background`) with cross-fade transitions when changing scenes.
  - Full-screen overlay support for `MEDIA` items of type `"CG"`.
- **Character Sprite Stage (`Poi`)**:
  - Supports up to 3 simultaneous character slots (`left`, `center`, `right`).
  - Active speaker is rendered at full opacity and slight scale-up; inactive sprites on stage are dimmed.
  - Smooth sprite swapping when a character changes expression (`123aaa:0` -> `123aaa:2`).
- **Dialogue Box (`DialogueBox`)**:
  - Positioned at the bottom of the screen.
  - Speaker nameplate badge showing `Profile.name`.
  - Typewriter text animation (`animated_text_kit`) with tap-to-complete (first tap finishes the typewriter animation; second tap advances to `engine.next()`).
- **Interactive Overlays**:
  - **`CHOICE` Modal**: Centered or bottom-anchored list of choice buttons over a dimmed stage; locked choices (failing `condition`) can either be hidden or shown disabled with a lock icon.
  - **`INPUT` Dialog**: Prompt modal with text field and confirmation button.
- **VN Quick Controls**:
  - **Backlog / History**: View recently spoken lines.
  - **Auto / Skip**: Auto-advance dialogue after a reading delay, or fast-forward previously read text.

---

## 3. Audio System (`AudioHelper`)

- **Background Music (BGM)**:
  - Loops `scene.music` via `AudioHelper`.
  - Avoids restarting the track if the new scene specifies the same `music` file already playing.
  - Automatically pauses on `AppLifecycleState.paused` and resumes on `AppLifecycleState.resumed`.
- **Sound Effects (SFX) & Voice Notes**:
  - Separate audio channel for one-shot UI/message sounds (`item.sfx`) and voice-overs/voice notes (`item.voice` or `MEDIA` audio) so BGM continues uninterrupted (or ducks slightly in volume).

---

## 4. Meta-Game Screens

1. **Collectibles Gallery**:
   - Grid view categorized into **Photos / CGs**, **Voice Notes**, and **Videos**.
   - Locked items display a silhouette/placeholder with a hint (e.g., *"Unlocked in Day 3"*); unlocked items (matched against `unlocked_media_ids`) can be viewed or replayed at any time.
2. **Endings Collection**:
   - Displays all story endings (`unlocked_ending_ids` vs. total endings), showing the ending badge (`TRUE`, `GOOD`, `BAD`, `SECRET`), title, and summary for completed routes.
3. **Chapter / Day Timeline**:
   - Visual node graph or Day list (`Day 1` ... `Day 7`) allowing players to jump to any unlocked checkpoint to try different choices without replaying from the beginning.
