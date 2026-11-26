import 'dart:io';

import 'package:path/path.dart' as p;

import 'cast.dart';
import 'config.dart';
import 'diagnostics.dart';
import 'model.dart';
import 'parser.dart';

/// A loaded story folder (spec §1): settings, cast, threads and every parsed script.
class StoryProject {
  /// The story folder as given, used to show paths. `null` for in-memory projects.
  final String? root;
  final StoryConfig config;
  final Cast cast;
  final List<ChannelDef>? channels;

  /// `clues.yaml`, when the story has one.
  final ClueFile? clues;
  final List<ScriptFile> scripts;

  /// The asset folder, when known.
  final String? assetsDir;

  /// Files in [assetsDir], relative to it with `/` separators. `null` when asset checks can't run.
  final Set<String>? assetFiles;

  /// Why asset checks can't run although an asset folder was set, e.g. it doesn't exist.
  final String? assetsError;

  /// Problems found while loading and parsing. Any error here stops `compile`.
  final Diagnostics diagnostics;

  StoryProject._({
    required this.root,
    required this.config,
    required this.cast,
    required this.channels,
    required this.clues,
    required this.scripts,
    required this.assetsDir,
    required this.assetFiles,
    required this.diagnostics,
    this.assetsError,
  });

  /// Every conversation in script path order, then file order.
  late final List<ConversationNode> conversations =
      List.unmodifiable([for (final script in scripts) ...script.conversations]);

  /// Conversations by key. The first one wins when a key is used twice (the linter reports it).
  late final Map<String, ConversationNode> conversationsByKey = () {
    final result = <String, ConversationNode>{};
    for (final conversation in conversations) {
      result.putIfAbsent(conversation.key, () => conversation);
    }
    return Map<String, ConversationNode>.unmodifiable(result);
  }();

  /// Builds a project from sources in memory, e.g. in tests. [scripts] maps paths to script text.
  factory StoryProject.fromSources({
    required String config,
    required String profiles,
    String? channels,
    String? clues,
    required Map<String, String> scripts,
    Set<String>? assetFiles,
  }) {
    final diagnostics = Diagnostics();
    final storyConfig = StoryConfig.parse(config, diagnostics);
    final parser = ScriptParser(storyConfig, diagnostics);
    final paths = scripts.keys.toList()..sort();
    return StoryProject._(
      root: null,
      config: storyConfig,
      cast: Cast.parse(profiles, storyConfig, diagnostics),
      channels: channels == null ? null : ChannelDef.parseAll(channels, storyConfig, diagnostics),
      clues: clues == null ? null : ClueFile.parse(clues, storyConfig, diagnostics),
      scripts: [for (final path in paths) parser.parse(path, scripts[path]!)],
      assetsDir: null,
      assetFiles: assetFiles,
      diagnostics: diagnostics,
    );
  }

  /// Loads the story folder at [root]. [assetsOverride] replaces the `assets` setting. Pass `loadAssets: false`
  /// when the caller doesn't inspect [assetFiles], to skip walking the asset directory.
  factory StoryProject.load(String root, {String? assetsOverride, bool loadAssets = true}) {
    final diagnostics = Diagnostics();
    String? read(String name) {
      final file = File(p.join(root, name));
      return file.existsSync() ? file.readAsStringSync() : null;
    }

    final config = StoryConfig.parse(read(StoryConfig.fileName), diagnostics);
    final channelsSource = read(ChannelDef.fileName);
    final cluesSource = read(ClueFile.fileName);
    final parser = ScriptParser(config, diagnostics);

    final scripts = <ScriptFile>[];
    final dir = Directory(root);
    if (dir.existsSync()) {
      final paths = dir
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => p.relative(file.path, from: root))
          .where((path) => path.endsWith(".cerita") && !p.split(path).any((part) => part.startsWith(".")))
          .map((path) => p.split(path).join("/"))
          .toList()
        ..sort();
      for (final path in paths) {
        scripts.add(parser.parse(path, File(p.join(root, path)).readAsStringSync()));
      }
      if (paths.isEmpty) diagnostics.error(null, "No .cerita scripts in $root");
    } else {
      diagnostics.error(null, "Story folder $root doesn't exist");
    }

    String? assetsDir;
    String? assetsError;
    Set<String>? assetFiles;
    if (assetsOverride != null) {
      assetsDir = assetsOverride;
    } else if (config.assets != null) {
      assetsDir = p.join(root, config.assets);
    }
    if (loadAssets && assetsDir != null) {
      final assets = Directory(assetsDir);
      if (assets.existsSync()) {
        assetFiles = assets
            .listSync(recursive: true)
            .whereType<File>()
            .map((file) => p.split(p.relative(file.path, from: assetsDir)).join("/"))
            .toSet();
      } else {
        assetsError = "Asset folder $assetsDir doesn't exist";
      }
    }

    return StoryProject._(
      root: root,
      config: config,
      cast: Cast.parse(read(Cast.fileName), config, diagnostics),
      channels: channelsSource == null ? null : ChannelDef.parseAll(channelsSource, config, diagnostics),
      clues: cluesSource == null ? null : ClueFile.parse(cluesSource, config, diagnostics),
      scripts: scripts,
      assetsDir: assetsDir,
      assetFiles: assetFiles,
      diagnostics: diagnostics,
      assetsError: assetsError,
    );
  }

  /// The engine reference for [ref] (`<id>:<sprite_index>` or `player`), or `null` after reporting why not.
  String? resolveProfile(ProfileRef ref, Diagnostics diagnostics) {
    if (ref.isPlayer) {
      if (ref.expression != null) diagnostics.error(ref.span, "The player has no expressions");
      return ProfileRef.player;
    }
    final profile = cast[ref.speaker];
    if (profile == null) {
      diagnostics.error(ref.span, "Unknown character '${ref.speaker}'");
      return null;
    }
    if (profile.expressions.isEmpty) {
      if (ref.expression != null) diagnostics.error(ref.span, "'${ref.speaker}' has no expressions");
      return profile.id;
    }
    final index = profile.spriteIndex(ref.expression);
    if (index == null) {
      diagnostics.error(
        ref.span,
        "Unknown expression '${ref.expression}' for '${ref.speaker}'. Known: ${profile.expressions.join(", ")}",
      );
      return null;
    }
    return "${profile.id}:$index";
  }
}
