import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../l10n/story_language.dart';
import '../player_prefs.dart';
import '../vn/dialogue_box.dart';

/// Text speed, auto-forward delay, skip and volumes. Changes are saved and applied right away.
/// With a [loader], each character with voiced lines gets its own voice volume.
class SettingsScreen extends StatefulWidget {
  final PlayerPrefs settings;
  final EngineLoader? loader;

  const SettingsScreen({super.key, required this.settings, this.loader});

  /// Characters with voiced lines in the story of [loader].
  static Future<List<Profile>> voicedCharacters(EngineLoader loader) async {
    final (package, catalog) = (await loader.initialLoad(), await StoryCatalog.load(loader));
    return [for (final id in catalog.voicedProfiles) ?package.profiles.byId(id)];
  }

  /// Typewriter speeds, slowest first. 0 is instant. Named by [CeritaStrings.textSpeeds].
  static const textSpeeds = [80, 60, 40, 25, 15, 0];

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PlayerPrefs get prefs => widget.settings;

  late final Future<List<Profile>> _voiced = switch (widget.loader) {
    final loader? => SettingsScreen.voicedCharacters(loader).catchError((_) => <Profile>[]),
    null => Future.value(const <Profile>[]),
  };

  @override
  void initState() {
    super.initState();
    prefs.load();
  }

  void _update(PlayerSettings Function(PlayerSettings settings) change) => prefs.update(change(prefs.value));

  /// Index in [SettingsScreen.textSpeeds] of the speed nearest to [msPerChar].
  int _speedIndex(int msPerChar) {
    var best = 0;
    for (final (index, speed) in SettingsScreen.textSpeeds.indexed) {
      if ((speed - msPerChar).abs() < (SettingsScreen.textSpeeds[best] - msPerChar).abs()) best = index;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = StoryLanguage.of(context);
    final strings = language.strings;
    final speedLabels = strings.textSpeeds;
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );

    Widget volume(String label, IconData icon, double value, PlayerSettings Function(double value) change) =>
        ListTile(
          leading: Icon(icon),
          title: Text(label),
          subtitle: Slider(
            value: value,
            divisions: 10,
            label: "${(value * 100).round()}%",
            onChanged: (value) => prefs.update(change(value)),
          ),
          trailing: SizedBox(width: 40, child: Text("${(value * 100).round()}%", textAlign: TextAlign.end)),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.settings),
        actions: [
          // The language is a setting too, but resetting the rest shouldn't switch it.
          TextButton(
            onPressed: () => prefs.update(PlayerSettings(locale: prefs.value.locale)),
            child: Text(strings.reset),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: prefs,
        builder: (context, settings, _) {
          final speed = _speedIndex(settings.textMsPerChar);
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (language.available.length > 1)
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: Text(strings.language),
                  subtitle: Text(language.languageName(language.locale ?? language.locales.source)),
                  onTap: () => LanguagePicker.show(context),
                ),
              header(strings.text),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
                // Keyed by speed, so the preview types out again when it changes.
                child: DialogueBox(
                  strings.textPreview,
                  key: ValueKey(settings.textMsPerChar),
                  speaker: strings.preview,
                  msPerChar: settings.textMsPerChar,
                ),
              ),
              ListTile(
                title: Text(strings.textSpeed),
                subtitle: Slider(
                  value: speed.toDouble(),
                  max: SettingsScreen.textSpeeds.length - 1.0,
                  divisions: SettingsScreen.textSpeeds.length - 1,
                  label: speedLabels[speed],
                  onChanged: (value) =>
                      _update((s) => s.copyWith(textMsPerChar: SettingsScreen.textSpeeds[value.round()])),
                ),
                trailing: SizedBox(width: 56, child: Text(speedLabels[speed], textAlign: TextAlign.end)),
              ),
              ListTile(
                title: Text(strings.autoForwardDelay),
                subtitle: Slider(
                  value: settings.autoDelayMs.clamp(400, 3000).toDouble(),
                  min: 400,
                  max: 3000,
                  divisions: 13,
                  label: "${(settings.autoDelayMs / 1000).toStringAsFixed(1)} s",
                  onChanged: (value) => _update((s) => s.copyWith(autoDelayMs: value.round())),
                ),
                trailing: SizedBox(
                  width: 56,
                  child: Text("${(settings.autoDelayMs / 1000).toStringAsFixed(1)} s", textAlign: TextAlign.end),
                ),
              ),
              SwitchListTile(
                title: Text(strings.skipUnread),
                subtitle: Text(strings.skipUnreadHint),
                value: settings.skipUnread,
                onChanged: (value) => _update((s) => s.copyWith(skipUnread: value)),
              ),
              header(strings.sound),
              volume(strings.music, Icons.music_note_outlined, settings.musicVolume,
                  (value) => settings.copyWith(musicVolume: value)),
              volume(strings.soundEffects, Icons.notifications_none, settings.soundVolume,
                  (value) => settings.copyWith(soundVolume: value)),
              volume(strings.voice, Icons.record_voice_over_outlined, settings.voiceVolume,
                  (value) => settings.copyWith(voiceVolume: value)),
              FutureBuilder(
                future: _voiced,
                builder: (context, snapshot) {
                  final characters = snapshot.data ?? const <Profile>[];
                  if (characters.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header(strings.characterVoices),
                      for (final profile in characters)
                        volume(profile.name, Icons.person_outline, settings.voiceVolumes[profile.id] ?? 1,
                            (value) => settings.copyWith(voiceVolumes: {...settings.voiceVolumes, profile.id: value})),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
