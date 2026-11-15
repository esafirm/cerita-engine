# Presentation Modes Specification

Cerita Engine separates narrative state from UI rendering. A story can use **Messenger / Chat Mode**, **Visual Novel Stage Mode**, or switch between them when `EngineListener.onNewScene(Scene)` fires.

---

## 1. Messenger / Chat Mode (*Salah Sambung 3* Style)

Activated when `scene.mode == "CHAT"`. Emulates a modern mobile messaging application.

### 1.1 Layout & Components
- **Top App Bar**:
  - Displays the active contact's avatar, `name`, online status or `bio` from `Profile`, and in-game `day` / `time` from `Scene`.
  - Action buttons for **Profile Details**, **Gallery**, **Case Board** (stories with clues, §6) and **Chapter/Settings**.
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
  - **Choice Selection (`CHOICE`)**: Expands a tray of selectable reply cards at the bottom of the chat (with an optional countdown bar if `timeout_ms` is set). An evidence question shows the Case Board picker there instead (§6.3), and the presented clue is sent as a clue message (§6.4).
  - **Text Input (`INPUT`)**: Activates the message text field and Send button.

---

## 2. Visual Novel (VN) Stage Mode

Activated when `scene.mode == "VN"` (default). Evolves `SimpleConversation`, `Poi`, and `DialogueBox`.

### 2.1 Layout & Components
- **Background Layer (`Poi`)**:
  - Full-screen scene background (`scene.background`) with cross-fade transitions when changing scenes.
  - Full-screen overlay support for `MEDIA` items of type `"CG"`.
- **Character Sprite Stage (`Poi`)**:
  - Supports up to 5 simultaneous character slots (`far_left`, `left`, `center`, `right`, `far_right`). The 3 inner slots keep their wide spacing until a `far_*` slot is used.
  - Characters are tracked by profile id, so moving one to another slot slides it across instead of fading it out and in.
  - Active speaker is rendered at full opacity and slight scale-up; inactive sprites on stage are dimmed.
  - Smooth sprite swapping when a character changes expression (`123aaa:0` -> `123aaa:2`).
- **Stage Direction (`STAGE` items)**:
  - Character and background `transition`s: `fade`, `dissolve`, `fade_black`, `slide_*`, `zoom`, `wipe_*`, `none`. Without one, the skin's default transition is used.
  - Camera: `shake` and `flash` play once; `zoom` scales the background and characters towards a slot.
  - Weather: a particle layer (`rain`, `snow`, `sakura`) between the characters and the dialogue box.
  - In Skip mode stage directions apply instantly.
- **Dialogue Box (`DialogueBox`)**:
  - Positioned at the bottom of the screen.
  - Speaker nameplate badge showing `Profile.name`.
  - Typewriter text animation with tap-to-complete (first tap finishes the typewriter animation; second tap advances to `engine.next()`).
  - Text tags (data schema §6): styles, `{shake}` / `{wave}` letters, speed changes and pauses. At a `{w}` the box shows its "next" indicator, and a tap types the rest of the line. The text keeps its final layout while it types, so words don't jump between lines.
- **Interactive Overlays**:
  - **`CHOICE` Modal**: Centered or bottom-anchored list of choice buttons over a dimmed stage; locked choices (failing `condition`) can either be hidden or shown disabled with a lock icon. Choice text can have text tags (data schema §6).
  - **`INPUT` Dialog**: Prompt modal with text field and confirmation button.
- **NVL Page** (`textbox: "nvl"`):
  - The lines of the current page fill a dimmed full-screen panel over the stage, newest at the bottom, older ones scrolling off the top. Characters stay visible behind the panel.
  - Speaker lines start with the character's name. Narration is plain. The player's answers are shown too.
  - Only the newest line types out. Choices and the input prompt appear over the page.
  - `STAGE` `page` actions and new conversations start a new page.
- **VN Quick Controls**:
  - **Backlog / History**: View recently spoken lines. Lines that can be rolled back to have a rewind button, and voiced lines a button to play their voice again.
  - **Back**: Rolls back to the previous line (engine §7). A mouse wheel scroll up does the same. Rolled-back lines and stage changes show instantly.
  - **Auto / Skip**: Auto-advance dialogue after a reading delay, or fast-forward previously read text (all text with the `skip_unread` setting).
  - **Quick Save / Quick Load**: Saves to and loads from the quick slot without leaving the stage.
  - **Hide**: Hides the dialogue box, overlays and controls to look at the stage or a CG. Any tap brings them back. Auto and skip wait while the UI is hidden and carry on when it comes back.
  - **Case Board**: Opens the board (§6) in stories with clues, with a badge counting new clues.

---

## 3. Audio System (`AudioHelper`)

- **Channels**: music, ambience, sound effects and voice. Music, sound and voice volumes come from the player settings, ambience follows the sound volume, and each character's voice can be turned down on its own. Ducking lowers the music relative to its setting.
- **Background Music (BGM)**:
  - Loops `scene.music` via `AudioHelper`.
  - Avoids restarting the track if the new scene specifies the same `music` file already playing.
  - A track change fades the old track out and the new one in (`fade_ms`, default 1 s). Stopping fades out too.
- **Ambience**: Loops `scene.ambience` / `STAGE` `ambience` under the music, with the same fades and lifecycle.
  - Automatically pauses on `AppLifecycleState.paused` and resumes on `AppLifecycleState.resumed`.
- **Sound Effects (SFX) & Voice Notes**:
  - Separate audio channel for one-shot UI/message sounds (`item.sfx`) and voice-overs/voice notes (`item.voice` or `MEDIA` audio) so BGM continues uninterrupted (or ducks slightly in volume).
  - Sound effects can overlap: a few players take turns.
  - A voice line stops when the story moves on. Its speaker's voice volume applies.
- **Voice per language**: voice-overs and voice notes resolve `name.<locale>.mp3` before `name.mp3` against the
  asset manifest (`LocalizedAssets`, loaded once per bundle). The active locale picks the clip. A voice note
  that is not playing reloads its clip after a language switch.

---

## 4. Meta-Game Screens

1. **Collectibles Gallery**:
   - Grid view categorized into **Photos / CGs**, **Voice Notes**, and **Videos**.
   - Locked items display a silhouette/placeholder with a hint (e.g., *"Unlocked in Day 3"*); unlocked items (matched against `unlocked_media_ids`) can be viewed or replayed at any time.
2. **Endings Collection**:
   - Displays all story endings (`unlocked_ending_ids` vs. total endings), showing the ending badge (`TRUE`, `GOOD`, `BAD`, `SECRET`), title, and summary for completed routes.
3. **Chapter / Day Timeline**:
   - Visual node graph or Day list (`Day 1` ... `Day 7`) allowing players to jump to any unlocked checkpoint to try different choices without replaying from the beginning.
   - **Replay** plays only that chapter (engine §8) and returns when it ends, without touching the saves.
4. **Save / Load Slots**:
   - Autosave, quick save and manual slots with chapter, title and time.
   - Each slot has a thumbnail drawn from its saved stage (background and characters). Chat and call saves show the mode instead.
5. **Music Room**:
   - Every track of the story, in story order. Tracks in `heard_music` can be played, the rest are locked.
6. **Settings**:
   - Text speed (with a preview line), auto-forward delay, skip unread text, and music / sound / voice volumes (engine §5.3). Changes apply right away, also to a running story.
   - A voice volume for each character with voiced lines.
   - Language, when the story offers more than one (§5).

---

## 5. Language

Implements [CE-01 Bilingual stories](backlog/01-bilingual-stories.md) in `cerita_flutter`.

### 5.1 `StoryLanguage`

A `ChangeNotifier` holding the active locale, the story's `StoryLocales` and the engine string tables. Apps
provide it above the navigator with `StoryLanguageScope`, the same way as `StorySkinScope`:

```dart
final language = StoryLanguage();
await language.load(setup); // reads index.json and the saved pick
runApp(MaterialApp(
  builder: (context, child) => StoryLanguageScope(language: language, child: child!),
  home: ...,
));
```

- `load(setup)` picks, in order: the saved language, the device language (PRD 10.6, D4), the story's
  `source_locale`. Saved and device languages only count if the story lists them in `locales`.
- `select(locale)` switches and saves it as `PlayerSettings.locale` through `StorySetup.settings`.
- `StoryLanguage.of(context)` returns the scope's language. Without a scope it is a fallback with English
  engine screens and the story in its source language, which is how the engine looked before CE-01.

`StoryScreen` passes the language to its `StoryController`, which sets `engine.locale` and re-reads the
current line, speaker, chapter and WAIT banner in the new language. Everything else re-renders from the
transcript (`controller.itemOf(entry)`), so a switch mid-chapter changes the current line, the backlog, chat
history and menus at once, without touching progress.

### 5.2 Engine screens (`CeritaStrings`)

Every string the engine draws itself (in-game menu, HUD, toasts, dialogs, chat and call chrome, Save, Load,
Chapters, Gallery, Endings, Settings and Music room screens, ending summary) comes from
`StoryLanguage.of(context).strings`, a `CeritaStrings`. Built in: `CeritaStrings.en` and `CeritaStrings.id`.

- **More languages**: subclass `CeritaStrings` and pass `StoryLanguage(strings: {"ja": JaStrings()})`.
- **Lookup**: the active locale, else English. Without a picked locale, English.
- **Skins** read `StoryLanguage.of(context)` for the locale and translate their own text. The default skin
  and `AnimeVnSkin` use `CeritaStrings` for their HUD labels.
- **Apps** can use the same strings for their title screen (`newGame`, `continueGame`, `load`, ...).

### 5.3 Language switch

`LanguagePicker.show(context)` lists the story's `locales` by their `CeritaStrings.languageName`. The Settings
screen shows a Language row when the story has more than one locale, and so does the demo title screen.

---

## 6. Case Board & Evidence

*Backlog CE-05 and CE-06.* Only for stories with a `clues.json` (data-schema §8). A story without clues shows
no board entry, button, badge or notification anywhere.

### 6.1 Case Board screen (`CaseBoardScreen`)
- **Entry points**: an in-game menu entry (with the count of new clues), a button in the VN HUD
  (`VnHud.onCaseBoard`, with the same count as a badge) and a button in the chat top bar.
- **Layout**: the found clues grouped by chapter, newest chapter first (data-schema §8.2). Each clue shows its
  title, its image as a thumbnail, a marker when it is a `key` clue, and a "New" highlight until viewed. With
  `show_counts`, each chapter heading says "3 of 5 found". Chapters with no clue found yet aren't shown.
  Before the first clue, the board says so.
- **Detail**: tapping a clue opens its title, image and full description. Tapping the image opens it full
  screen with pinch to zoom.
- **Viewed**: closing the board marks every clue it showed as viewed (engine §10.2), which clears the
  highlights and the count.
- **Pausing**: while the board is open the story holds: chat pacing, auto and skip wait, and a timed choice's
  countdown stops. Closing the board resumes them.

### 6.2 Clue notification
- When a clue is found (`EngineListener.onClueFound`), a short notification slides in at the top: "Clue found:
  Pier photo", with the clue's image if it has one. It disappears after about 3 seconds. Several clues found at
  once queue up.
- Tapping it opens the board at that clue's detail.

### 6.3 Picker mode (evidence questions)
- When the story reaches an evidence question, its prompt is shown as for a `CHOICE` (dialogue box, NVL page
  or chat tray). Once the prompt has been read, the board opens in picker mode: in VN over the dimmed stage, in
  chat in place of the reply tray.
- The picker lists every clue found in this playthrough (PRD CE-06 D1), grouped like the board, with the
  prompt on top. Tapping a clue opens its detail with **Present** and **Back**. Presenting needs this second
  tap, so a stray tap can't answer.
- With `timeout_ms`, a countdown bar runs over the picker, as for timed choices. When it runs out the picker
  closes and the timeout outcome plays.
- The board's normal entry points are hidden while the picker is open, and saving is unavailable, as for any
  pending choice.

### 6.4 Presented clue
- **VN**: the backlog and the NVL page show the player's line as "Presented: Pier photo".
- **Chat**: the clue is sent as an outgoing message: its image (tap to view full screen) with the title under
  it, or the title alone with a clue icon when it has no image. It stays in chat history.
- **Call**: the player's line shows "Presented: Pier photo".

### 6.5 Skin hooks
The board and the notification are drawn through `StorySkin`, so a game can make them a cork board, a notebook
or a case file:

| Hook | Draws |
| :--- | :--- |
| `caseBoardBackground(context, child)` | The board's backdrop behind the clue list, for the board and the picker. Default: the theme surface |
| `clueGroupHeader(context, ClueGroupHeader)` | A chapter heading, with its found and total counts when `show_counts` is on |
| `clueCard(context, ClueCard)` | One clue on the board or in the picker: title, image, key marker, "New" highlight and tap handler |
| `clueNotification(context, ClueNotice)` | The "Clue found" notification |

Hooks get the clue's text already resolved, the image's asset path and the callbacks.
