import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/foundation.dart';

/// The player's [PlayerSettings], loaded from and saved to a [StoryStorage]. Story screens listen
/// to it, so changes apply to a running story.
class PlayerPrefs extends ValueNotifier<PlayerSettings> {
  final StoryStorage storage;
  Future<void>? _loading;
  bool _updated = false;

  PlayerPrefs(this.storage) : super(const PlayerSettings());

  /// Loads the stored settings once. Later calls return the same future.
  Future<void> load() => _loading ??= storage.loadSettings().then((settings) {
        if (!_updated) value = settings;
      });

  Future<void> update(PlayerSettings settings) async {
    _updated = true;
    value = settings;
    await storage.saveSettings(settings);
  }
}
