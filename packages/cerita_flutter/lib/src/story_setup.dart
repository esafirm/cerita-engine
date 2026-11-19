import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/widgets.dart';

import 'asset_engine_loader.dart';
import 'audio_helper.dart';
import 'l10n/localized_assets.dart';
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

  /// Finds per-locale voice clips.
  final LocalizedAssets assets;

  /// Asked before the story enters each conversation, see [StoryGate]. Null lets the story go anywhere.
  final StoryGate? gate;

  /// The screen shown over the story when [gate] keeps it out of a conversation, e.g. a store page. Null shows
  /// a plain notice with a way back.
  final StoryGateBuilder? gateBuilder;

  StorySetup({
    required this.config,
    required this.loader,
    required this.storage,
    PlayerPrefs? settings,
    this.audio = AudioHelper.new,
    this.developer = false,
    LocalizedAssets? assets,
    this.gate,
    this.gateBuilder,
  })  : settings = settings ?? PlayerPrefs(storage),
        assets = assets ?? LocalizedAssets();

  factory StorySetup.assets({
    LoaderConfig config = const LoaderConfig(),
    StoryStorage? storage,
    bool developer = false,
    AssetBundle? bundle,
    StoryGate? gate,
    StoryGateBuilder? gateBuilder,
  }) {
    return StorySetup(
      config: config,
      loader: AssetEngineLoader(config, bundle: bundle),
      storage: storage ?? SharedPrefsStoryStorage(),
      developer: developer,
      assets: LocalizedAssets(bundle),
      gate: gate,
      gateBuilder: gateBuilder,
    );
  }

  /// CGs live in `bg/`; photos, voice notes and videos in `media/`.
  String mediaPath(MediaItemType item) => config.mediaPath(item);
}

/// What [StorySetup.gateBuilder] gets when the gate keeps the story out of [conversation].
class StoryGateRequest {
  final Conversation conversation;

  /// Plays on from where the story stood before the gate, once it may have opened (e.g. after a purchase). Null
  /// when there's nowhere to play on from, as in a chapter replay.
  final Future<void> Function()? reopen;

  /// Closes the story screen.
  final VoidCallback leave;

  const StoryGateRequest({required this.conversation, required this.reopen, required this.leave});
}

typedef StoryGateBuilder = Widget Function(BuildContext context, StoryGateRequest request);
