import 'package:flutter/material.dart';

/// Maps every engine capability to where the demo story "Wrong Number" shows it.
class CapabilitiesScreen extends StatelessWidget {
  const CapabilitiesScreen({super.key});

  static const _sections = [
    (
      "Presentation modes",
      [
        ("VN stage", "Prologue & Day 2: backgrounds, 3 sprite slots, speaker focus, typewriter, CG overlay."),
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
      ],
    ),
    (
      "State",
      [
        ("Conditions", "Item and choice conditions with ==, !=, >=, &&, ||, ! and unset defaults."),
        ("Effects", "set / add / subtract on miki_trust, luna_affection, flags. See Menu → Story variables."),
        ("Interpolation", "{{NAME}} in dialogue, choices and chat bubbles."),
      ],
    ),
    (
      "Persistence & meta",
      [
        ("Autosave & slots", "Continue from the title, or save to 3 manual slots from the in-game menu."),
        ("Transcript", "Chat history and VN backlog survive app restarts."),
        ("Gallery", "Locked silhouettes with unlock hints; photos, voice notes and videos replay any time."),
        ("Endings", "Collection with unlocked / total progress."),
        ("Chapters", "Jump back to Prologue, Day 1 or Day 2 with the variables you had there."),
        ("Auto / Skip", "VN quick controls; Skip only fast-forwards lines read in an earlier playthrough."),
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
