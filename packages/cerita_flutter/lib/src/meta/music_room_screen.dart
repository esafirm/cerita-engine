import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../audio_helper.dart';
import '../story_setup.dart';

/// Every track of the story. Tracks the player has heard can be played, the rest are locked.
class MusicRoomScreen extends StatefulWidget {
  final StorySetup setup;

  const MusicRoomScreen({super.key, required this.setup});

  /// `night_ambience.mp3` → `Night Ambience`.
  static String titleOf(String file) {
    final name = file.split("/").last;
    final dot = name.lastIndexOf(".");
    return (dot > 0 ? name.substring(0, dot) : name)
        .split(RegExp(r"[_\-\s]+"))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(" ");
  }

  @override
  State<MusicRoomScreen> createState() => _MusicRoomScreenState();
}

class _MusicRoomScreenState extends State<MusicRoomScreen> {
  late final AudioHelper _audio = widget.setup.audio();
  late final Future<(List<String>, Set<String>)> _tracks = _load();
  String? _playing;

  Future<(List<String>, Set<String>)> _load() async {
    final catalog = await StoryCatalog.load(widget.setup.loader);
    final meta = await widget.setup.storage.loadMeta();
    return (catalog.music, meta.heardMusic);
  }

  @override
  void initState() {
    super.initState();
    _audio.addObserver();
    final settings = widget.setup.settings;
    settings.load().then((_) {
      final value = settings.value;
      _audio.setVolumes(music: value.musicVolume, sound: value.soundVolume, voice: value.voiceVolume);
    });
  }

  @override
  void dispose() {
    _audio
      ..stopAll()
      ..removeObserver();
    super.dispose();
  }

  void _toggle(String file) {
    final playing = _playing == file ? null : file;
    _audio.playBgm(playing == null ? null : widget.setup.config.music(playing));
    setState(() => _playing = playing);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text("Music room")),
      body: FutureBuilder(
        future: _tracks,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("${snapshot.error}"));
          final data = snapshot.data;
          if (data == null) return const Center(child: CircularProgressIndicator());
          final (tracks, heard) = data;
          if (tracks.isEmpty) return const Center(child: Text("This story has no music."));
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text("${tracks.where(heard.contains).length} / ${tracks.length} tracks heard"),
              ),
              for (final (index, file) in tracks.indexed)
                ListTile(
                  enabled: heard.contains(file),
                  leading: CircleAvatar(
                    backgroundColor: _playing == file ? scheme.primary : scheme.surfaceContainerHighest,
                    foregroundColor: _playing == file ? scheme.onPrimary : scheme.onSurfaceVariant,
                    child: Icon(switch (file) {
                      _ when !heard.contains(file) => Icons.lock_outline,
                      _ when _playing == file => Icons.pause,
                      _ => Icons.play_arrow,
                    }),
                  ),
                  title: Text(heard.contains(file) ? MusicRoomScreen.titleOf(file) : "Track ${index + 1}"),
                  subtitle: Text(heard.contains(file) ? file : "Not heard yet"),
                  onTap: heard.contains(file) ? () => _toggle(file) : null,
                ),
            ],
          );
        },
      ),
    );
  }
}
