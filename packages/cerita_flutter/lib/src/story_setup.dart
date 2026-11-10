import 'package:cerita_core/cerita_core.dart';

import 'asset_engine_loader.dart';
import 'shared_prefs_story_storage.dart';

/// Everything a story screen needs: asset locations, the loader and the save storage.
class StorySetup {
  final LoaderConfig config;
  final EngineLoader loader;
  final StoryStorage storage;

  const StorySetup({required this.config, required this.loader, required this.storage});

  factory StorySetup.assets({LoaderConfig config = const LoaderConfig(), StoryStorage? storage}) {
    return StorySetup(
      config: config,
      loader: AssetEngineLoader(config),
      storage: storage ?? SharedPrefsStoryStorage(),
    );
  }

  /// CGs live in `bg/`; photos, voice notes and videos in `media/`.
  String mediaPath(MediaItemType item) => item.mediaType == MediaType.cg ? config.bg(item.uri) : config.media(item.uri);
}
