# Presentation Modes Specification

Cerita Engine separates narrative state from UI rendering. A story can use **Messenger / Chat Mode**, **Visual Novel Stage Mode**, or switch between them when `EngineListener.onNewScene(Scene)` fires.

---

## 1. Messenger / Chat Mode (*Salah Sambung 3* Style)

Activated when `scene.mode == "CHAT"`. Emulates a modern mobile messaging application.

### 1.1 Layout & Components
- **Top App Bar**:
  - Displays the active contact's avatar and `name`, and under them a subtitle: the scene's `time`, then the status.
  - The time is written the way the player's language writes a time, like the story's own timestamps: `"23:58"` shows as `"11:58 PM"` in English and `"23.58"` in Indonesian (`CeritaStrings.clock`). Time that isn't `HH:MM` shows as written. The header shows no day: a messenger doesn't, and the chapter and the story's timestamps already say it.
  - The status is the scene's `status` when it sets one (data schema §3), else the channel's `status`, else the contact's `bio`. A scene with `"status": null` shows none, for a flashback where the channel's "last seen" would contradict the story.
  - The time comes first and the subtitle wraps onto a second line before it is cut, so a long status is what gets cut short, never the time. While a message is being typed the subtitle says so instead (`"typing…"`).
  - Action buttons for **Profile Details**, **Gallery**, **Case Board** (stories with clues, §6) and **Chapter/Settings**.
- **Scrollable Message Timeline**:
  - Renders the delivered transcript for the active `channel_id`.
  - **Incoming Bubbles**: Left-aligned with character avatar and name; styled according to character theme.
  - **Outgoing (Player) Bubbles**: Right-aligned; automatically appended when the player selects a `CHOICE` or submits an `INPUT`.
  - **Someone else's phone**: a thread with an `owner` (data schema §2, chat threads) is on that character's phone. Their messages are outgoing bubbles, and their typing isn't shown, so the player reads the thread the way its owner saw it.
  - **System / Timestamp Dividers**: Centered pills for `NARRATION` items (`"Day 2 — 09:15 AM"`, `"Luna sent a photo"`).
- **Typing Indicator & Pacing**:
  - When the next item is an incoming `TEXT` or `MEDIA` item with `typing_delay_ms`, displays an animated typing bubble (`"Miki is typing..."`) before revealing the message and playing a notification SFX.
- **Rich Media Bubbles (`MEDIA`)**:
  - **Photo (`IMAGE`)**: Inline thumbnail with optional caption; tapping opens a full-screen pinch-to-zoom viewer.
  - **Voice Note (`AUDIO`)**: Inline audio player bubble with play/pause button, waveform/progress bar, duration, and optional transcript toggle.
  - **Video (`VIDEO`)**: Inline preview with play overlay.
- **Bottom Composer / Interaction Tray**:
  - **Normal Progression**: the thread moves on by itself, at the chat pacing.
  - **End of a scene**: when the thread has played out and the story would leave it next (another mode or thread, a new chapter, or the end), the tray shows **Tap to continue** and the story waits for a tap there or on the thread (§7).
  - **Choice Selection (`CHOICE`)**: Expands a tray of selectable reply cards at the bottom of the chat (with an optional countdown bar if `timeout_ms` is set). An evidence question shows the Case Board picker there instead (§6.3), and the presented clue is sent as a clue message (§6.4).
  - **Text Input (`INPUT`)**: Activates the message text field and Send button. With `"keyboard": "digits"` the number pad opens and only digits can be typed. Typing stops at `max_length`, and Send stays disabled until the answer has `min_length` characters (data schema §4.5). The VN dialog and the call view use the same field.

### 1.2 Phone calls (`CALL` scenes)
- **Layout**: like a phone's call screen. The caller's avatar and name over the blurred scene background, a status line (the call timer once the first line is spoken, or a narration line), the line being said as a caption, and the call buttons at the bottom. A tap anywhere else moves the call on.
- **Ringing** (`scene.ring`, data schema §3): the call is incoming. The phone rings with the `ring` sound on loop and vibrates, the status reads "Incoming call", and the story waits with its first line until the player taps **Answer**. Without `ring` the call is already connected when the scene starts, like a call the player makes.
- **Call buttons**: every one works.
  - **Mute** and **Speaker** toggle. Mute shows a muted microphone next to the status.
  - **Keypad** swaps the buttons for a dial pad that plays key clicks and shows the keys pressed. **Hide** brings the buttons back.
  - **Hold** stops the line and the story, and the status reads "On hold". Taking the call off hold says the line again.
  - **End call** and **Decline**: with the scene's `hangup` target (data schema §3) the call ends ("Call ended") and the story goes on there after a moment. Without it the call can't be ended: the player's character says why in a narration card over the buttons (the scene's `stay` line, or "Not now. I need to hear this."), and the call goes on ringing or talking. The card goes after about 3 seconds.
- **Choices, inputs and evidence** take the place of the call buttons while they are open.

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
  - **One scale for the cast**: a profile's `height` and `face` (data schema §2) size its sprites against the others, like one camera on everyone. The face says how big the art draws the character: a person's eyes to chin is about 1/15 of their height and their eyes sit at 14/15 of it, so every face comes out in proportion to its character's height and every eye line at its height, whether the art cuts a character at the knee or the thigh, or draws a small face on a long frame. The sprite cut highest up the body sits on the stage's bottom edge and the others reach below it. The top of the highest sprite of the whole cast reaches 82% of the stage height, and a character keeps their size whoever else is on stage. Without heights every sprite is as tall and stands on the bottom edge.
  - **Crowds**: on a narrow (portrait) stage the camera barely pulls back for a crowd (80% with two, 66% with three or more) and the characters overlap a little instead of shrinking into dolls against the background. Two or more stand evenly around the middle, left to right in slot order, half the stage width apart with two and 34% with three, so all three faces stay clear. A lone character stands at its slot, kept on screen. On a wide stage the slots are fixed shares of the width, the far ones half on screen, and the size drops to 66% with three or more. When a character enters or leaves, the others ease to their new size over the sprite transition. Characters keep a fixed paint order: the speaker is not moved to the front.
  - A line spoken by someone off stage (`offstage`, data schema §4.1) leaves the stage as it is and dims everyone on it.
  - An expression change fades the new sprite in over the old one, then fades the old one out under it, so the character is never see-through midway. The change starts once the new sprite is decoded: until then the old one stays, so a pose not shown before doesn't blink out on a slow phone.
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
  - **Hide**: Hides the dialogue box, overlays and controls to look at the stage or a CG. Any tap brings them back. Holding the stage anywhere but a control does the same until the finger lifts (`HoldToPeek`: a hold that starts on a button, a choice or a menu entry does nothing). Anything with a `MouseRegion`, which every `InkWell` and Material button has, counts as a control, so a skin's own buttons made of a plain `GestureDetector` wrap it in one. Auto and skip wait while the UI is hidden and carry on when it comes back.
  - **Case Board**: Opens the board (§6) in stories with clues, with a badge counting new clues.
  - **End of a scene**: a stage direction or wait that ends a scene leaves a pulsing **Tap to continue** over the stage, and the next scene waits for the tap (§7).

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
3. **Chapters** (CE-07):
   - Two views of the checkpoints, switched from the app bar: a **flowchart** and a **list**. The flowchart is the
     default when the story branches (a node leads to two or more nodes), otherwise the list.
   - **Flowchart**: the route map (authoring tools §2.1) drawn top to bottom, one row per layer, with lines from each
     node to the nodes it leads to. Reached checkpoints show their chapter (or day) and title, and how many of the
     endings after them were found ("1 of 3 endings found"). Unreached checkpoints show "???" and can't be tapped.
     Reached endings show their badge and title, unreached ones only a lock.
   - **Flowchart layout**: the chart fits the screen's width and only scrolls down. Nodes are at least 136 dp wide
     (two fit across a 320 dp phone, at most 200 dp), so as many columns as fit. A row with more nodes than columns
     wraps onto more lines: checkpoints first, then endings, every line on the first line's columns. Lines into and
     out of a wrapped row run down the gaps between its columns, never under a node. A title wraps to two lines and
     the endings count is never cut. Every node is as tall as the tallest reached node's text in the player's
     language and text size.
   - Tapping a reached checkpoint offers **Play from here** (continue from the checkpoint with its saved variables)
     and **Replay this chapter**, the same as the list.
   - **List**: every checkpoint in day order with a timeline, as before. Unlocked ones continue from there, and a
     button replays just that chapter.
   - **Replay** plays only that chapter (engine §8) and returns when it ends, without touching the saves.
4. **Save / Load Slots**:
   - Autosave, quick save and manual slots with chapter, title and time.
   - Each slot has a thumbnail drawn from its saved stage (background and characters). Chat and call saves show the mode instead.
5. **Music Room**:
   - Every track of the story, in story order. Tracks in `heard_music` can be played, the rest are locked.
6. **Settings**:
   - Text speed (with a preview line), auto-forward delay, skip unread text, chat pacing (from the author's pace to instant), and music / sound / voice volumes (engine §5.3). Changes apply right away, also to a running story.
   - A voice volume for each character with voiced lines.
   - Language, when the story offers more than one (§5).
7. **Credits** (CE-08):
   - Shown from the title screen when the story has a `credits.json` (data schema §9). Without one, apps leave the entry out (`loader.loadCredits()` returns null).
   - The sections with each person and role, then the third-party assets with title, author, source, license and note, in the active language. A button at the end opens the open-source licenses page (`showLicensePage`).
   - **Rolling credits**: when the player leaves the summary of an ending listed in `roll_after` (Back to title or All endings), the credits scroll up over black, then the game goes where the player asked. A tap skips them.
   - Skins restyle both through `StorySkin.credits`.

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
- **Detail**: tapping a clue opens a sheet (§7.2) with its title in the header, a key-clue marker, its image and full
  description. Tapping the image opens it in a full-screen sheet with pinch to zoom.
- **Viewed**: closing the board marks every clue it showed as viewed (engine §10.2), which clears the
  highlights and the count.
- **Pausing**: while the board is open the story holds: chat pacing, auto and skip wait, and a timed choice's
  countdown stops. Closing the board resumes them.

### 6.2 Clue notification
- When a clue is found (`EngineListener.onClueFound`), a short notification slides in at the top: "Clue found:
  Pier photo", with the clue's image if it has one. It disappears after about 3 seconds. Several clues found at
  once queue up. In VN it slides in under the HUD, so the HUD's buttons stay usable (a bar wrapped in
  `ClueNotifications.below` is kept clear).
- Tapping it opens the board at that clue's detail.
- No notification shows during an evidence question (§6.3), in any mode: it would cover the picker and open
  the board the question hides. Notifications still queued when the question comes are dropped. Their clues
  stay new, so the picker lists them and the board's badge counts them once the question is answered.

### 6.3 Picker mode (evidence questions)
- When the story reaches an evidence question, its prompt is shown as for a `CHOICE` (dialogue box, NVL page
  or chat tray). Once the prompt has been read, the board opens in picker mode: in VN over the dimmed stage, in
  chat in place of the reply tray.
- In VN the picker fills the space below the HUD, so nothing covers its prompt or countdown, and the HUD's
  backlog stays at hand to read again what was said.
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
- **Call**: the picker opens in place of the call buttons. The call view shows no player lines, so the presented
  clue appears in the backlog only.

### 6.5 Skin hooks
The board and the notification are drawn through `StorySkin`, so a game can make them a cork board, a notebook
or a case file:

| Hook | Draws |
| :--- | :--- |
| `caseBoardBackground(context, child)` | The board's backdrop behind the clue list, for the board and the picker. Default: the theme surface |
| `clueGroupHeader(context, ClueGroupHeader)` | A chapter heading, with its found and total counts when `show_counts` is on |
| `clueCard(context, ClueCard)` | One clue on the board or in the picker: title, image, key marker, "New" highlight and tap handler |
| `clueNotification(context, ClueNotice)` | The "Clue found" notification |

Hooks get the clue's text already resolved in the active language, the image's asset path and the callbacks.
Every label (board title, "New", "Clue found", "Present", "Presented", the counts) comes from `CeritaStrings`
(§5.2), in English and Indonesian.

---

## 7. Between scenes and sheets

### 7.1 The end of a scene
A scene that plays out by itself doesn't cut straight to the next one. When the story would leave the scene
before it shows anything else (`RealFsseEngine.peekExit`: the conversation runs out, or jumps into a conversation
with its own scene, or the story ends), and nothing but the clock would move it on (chat pacing, a `wait`, a
stage direction), it waits for a tap: `StoryController.sceneEndHeld`. The chat tray shows a **Tap to continue**
button, the VN stage and the call screen a pulsing **Tap to continue** pill.

What counts as leaving follows what the player sees switch: another mode or thread, any new VN conversation, a
new chapter (its card) or the end of the story. A chat that goes on in the same thread, with no new chapter,
moves on by itself. Auto and Skip don't wait: the player asked the story to move for them. A scene whose last line
already waits for a tap (a VN line, a call line) needs no extra one.

### 7.2 Sheets (`StorySheet`)
Every bottom sheet of the engine opens through `StorySheet.show`: the in-game menu, the backlog, a clue's detail,
a chapter's actions on the route chart, a picture shown full screen and the developer tools. They share one
frame, drawn by `StorySkin.sheet(context, StorySheetFrame)`: a handle, a header with an icon, the title and a
close button, and the body under a rule. A sheet is as tall as its body, but at least 40% of the screen and at
most 88%, and its body scrolls from there. The developer tools take the full 88% (`expand`). A picture takes the
whole screen below the status bar (`fullScreen`), in the same frame (`StorySheet.frame`).

- **In-game menu**: the main actions as a row of big buttons (`StorySheetAction`): Save, Load, Case Board (with
  its new-clue count) and Backlog. Settings, Gallery, Endings, Story variables and Developer follow as a list,
  and Back to title is set apart at the end.
- **Backlog**: the transcript, newest line at the bottom. A short backlog starts at the top of a 40% sheet.
- **Clue detail**: the clue's title in the header, then the key-clue marker, its image and its description.
  An expand mark on the image says a tap opens it full screen.
- **Picture** (`ImageViewerPage.open`, from a clue, a chat photo or the gallery): "Photo" in the header, the
  picture with pinch to zoom, and its caption under it. It grows out of the thumbnail that was tapped while the frame
  fades in around it, and shrinks back into the thumbnail on close. It has its own route rather than a modal
  bottom sheet, because the frame fades instead of sliding up, and the picture flies above that fade.

The default frame is a raised panel with rounded top corners. Last Seen draws it as one of its framed windows,
with an uppercase title, a dotted rule and a CLOSE tag.
