import 'package:cerita_core/cerita_core.dart';

import 'asset_engine_loader.dart';
import 'audio_helper.dart';
import 'player_prefs.dart';
import 'shared_prefs_story_storage.dart';

/// Everything a story screen needs: asset locations, the loader, the save storage, the player settings
/// and the audio.
class StorySetup {
  final LoaderConfig config;
  final EngineLoader loader;
  final StoryStorage storage;
  final PlayerPrefs settings;

  /// Creates the audio of each story screen, which disposes it when it closes.
  final AudioHelper Function() audio;

  /// Adds the developer panel to the in-game menu: variables, jumps, story check and reload.
  /// For writers, keep it off in release builds.
  final bool developer;

  StorySetup({
    required this.config,
    required this.loader,
    required this.storage,
    PlayerPrefs? settings,
    this.audio = AudioHelper.new,
    this.developer = false,
  }) : settings = settings ?? PlayerPrefs(storage);

  factory StorySetup.assets({LoaderConfig config = const LoaderConfig(), StoryStorage? storage, bool developer = false}) {
    return StorySetup(
      config: config,
      loader: AssetEngineLoader(config),
      storage: storage ?? SharedPrefsStoryStorage(),
      developer: developer,
    );
  }

  /// CGs live in `bg/`; photos, voice notes and videos in `media/`.
  String mediaPath(MediaItemType item) => config.mediaPath(item);
}
