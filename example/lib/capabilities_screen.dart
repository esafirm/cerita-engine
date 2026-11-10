import 'package:flutter/material.dart';

/// Maps every engine capability to where the demo story "Wrong Number" shows it.
class CapabilitiesScreen extends StatelessWidget {
  const CapabilitiesScreen({super.key});

  static const _sections = [
    (
      "Presentation modes",
      [
        ("VN stage", "Prologue & Day 2: backgrounds, 5 sprite slots, speaker focus, typewriter, CG overlay."),
        ("Messenger", "Day 1: chat thread, typing indicator, system pills, photo / voice note / video bubbles."),
        ("Call", "Pick \"Let me call you\" on Day 1: caller card, call timer, voice-over captions."),
        ("Mode switching", "Prologue (VN) → Day 1 (Chat) → Call → Day 2 (VN) → Chat or VN endings."),
      ],
    ),
    (
      "Item types",
      [
        ("TEXT", "Positions, typing_delay_ms, sfx and voice-over (Nora, Miki, Luna)."),
        ("NARRATION", "narration in VN, system and timestamp pills in chat."),
        ("MEDIA", "IMAGE, AUDIO (with transcript), VIDEO and CG, all with gallery unlock IDs."),
        ("CHOICE", "Effects, conditional locked options, and a 10s timed reply with default_choice on Day 1."),
        ("INPUT", "Player name with default_value, and the Day 2 passcode puzzle (hint: listen to the call)."),
        ("BRANCH", "Prologue fallback route and the Day 2 ending router."),
        ("WAIT", "Real-time pause with an in-app notification banner."),
        ("ENDING", "Four endings: TRUE, GOOD, BAD and SECRET."),
        ("JUMP & labels", "Prologue: \"Who had this number before you?\" jumps to #old_number and back to the #ask menu."),
        ("CALL / RETURN", "The phone buzz is a shared subroutine in cvn_shared.json, called from the prologue."),
        ("SET", "Silent state changes: run counter, a random greeting on Day 2, the Day 2 bond score."),
      ],
    ),
    (
      "Stage direction",
      [
        ("Show / hide / move", "Nora slides up in the prologue and walks left at night. Miki fades in beside Luna on Day 2."),
        ("Background transitions", "Prologue: fade through black to night (pick \"Nah\")."),
        ("Camera", "Shake when the phone buzzes, a lavender flash for Miki, a slow zoom in the true ending."),
        ("Weather", "Sakura petals as Miki leaves in the true ending."),
        ("Music & sound", "Prologue, pick \"Nah\": the music fades out and the night ambience fades in under it. Saved with the slot."),
      ],
    ),
    (
      "Text & audio",
      [
        ("Text tags", "Prologue & Day 2: {i}, {b}, {color}, {shake}, {wave}, timed pauses {w=…} and tap-to-continue {w}."),
        ("Interrupted lines", "Day 2: Nora gets cut off mid-sentence with {nw}."),
        ("NVL mode", "The prologue opens as a full-screen page, then switches to the dialogue box. The secret ending is a diary page."),
        ("Music fades & ambience", "Track changes fade. Prologue, pick \"Nah\": a looping ambience track plays under the stage."),
        ("Voices", "LOG → speaker button replays a voiced line. Settings → Character voices sets each character's volume."),
        ("Sound effects", "Several can play at once instead of cutting each other off."),
      ],
    ),
    (
      "State",
      [
        ("Conditions", "Item and choice conditions with ==, !=, >=, &&, ||, ! and unset defaults."),
        ("Effects", "set / add / subtract on miki_trust, luna_affection, flags. See Menu → Story variables."),
        ("Interpolation", "{{NAME}} in dialogue, choices and chat bubbles."),
        ("Expressions", "Day 2: random(1, 2) picks Luna's greeting, bond = miki_trust + luna_affection."),
        ("Persistent variables", "persistent.runs counts new games. Start a second one and Nora notices."),
        ("Once choices", "The prologue question disappears after you ask it. Choices picked before get a check mark."),
      ],
    ),
    (
      "Persistence & meta",
      [
        ("Autosave & slots", "Continue from the title, or save to 3 manual slots from the in-game menu."),
        ("Save thumbnails", "Each slot shows its saved stage: background and characters."),
        ("Transcript", "Chat history and VN backlog survive app restarts."),
        ("Gallery", "Locked silhouettes with unlock hints; photos, voice notes and videos replay any time."),
        ("Endings", "Collection with unlocked / total progress."),
        ("Chapters", "Jump back to Prologue, Day 1 or Day 2 with the variables you had there."),
        ("Scene replay", "Chapters → replay button: plays only that chapter, then comes back. Saves are untouched."),
        ("Music room", "Title → Music: every track you have heard. The night track unlocks on Day 1."),
      ],
    ),
    (
      "Player controls",
      [
        ("Rollback", "BACK (or scroll up) returns to the previous line. Back at the prologue menu, pick another answer."),
        ("Backlog jump", "LOG: the rewind button next to a VN line goes straight back to it."),
        ("Quick save / load", "Q.SAVE and Q.LOAD on the VN stage."),
        ("Hide", "HIDE clears the dialogue box and controls to look at the stage or a CG. Tap to bring them back."),
        ("Auto / Skip", "VN quick controls. Skip only fast-forwards lines read before, unless the setting says otherwise."),
        ("Settings", "Title → Settings or Menu → Settings: text speed with a preview, auto delay, skip unread, volumes."),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Capabilities")),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final (title, items) in _sections) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(title, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
            ),
            for (final (name, description) in items)
              ListTile(dense: true, title: Text(name), subtitle: Text(description)),
          ],
        ],
      ),
    );
  }
}
