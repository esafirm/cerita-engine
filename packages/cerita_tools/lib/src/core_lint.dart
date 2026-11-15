import 'dart:convert';

import 'package:cerita_core/cerita_core.dart' as core;

import 'cast.dart';
import 'diagnostics.dart';
import 'model.dart';
import 'project.dart';

/// Serves compiled story files from memory, the way the Flutter asset loader serves them from the bundle.
class CompiledStoryLoader extends core.EngineLoader {
  /// File name to decoded JSON.
  final Map<String, Object?> files;

  CompiledStoryLoader(this.files);

  /// Decodes the output of `compileStory`.
  factory CompiledStoryLoader.fromCompiled(Map<String, String> compiled) =>
      CompiledStoryLoader({for (final MapEntry(:key, :value) in compiled.entries) key: jsonDecode(value)});

  Map<String, dynamic> _json(String name) {
    final json = files[name];
    if (json == null) throw StateError("No $name");
    return Map<String, dynamic>.from(json as Map);
  }

  @override
  Future<core.EnginePackage> initialLoad() async => core.EnginePackage(
        conversation: await loadConversation(core.Conversation.indexKey),
        profiles: core.ProfileData.fromJson(_json("profiles.json")),
        channels: files.containsKey("channels.json") ? core.Channel.listFromJson(_json("channels.json")) : const [],
      );

  @override
  Future<core.Conversation> loadConversation(String conversationId) async {
    final key = conversationId.startsWith("cvn_") ? conversationId.substring(4) : conversationId;
    final name = key == core.Conversation.indexKey ? "index.json" : "cvn_$key.json";
    return core.Conversation.fromJson(_json(name), key: key);
  }

  @override
  Future<List<String>> listConversationKeys() async => [
        core.Conversation.indexKey,
        for (final name in files.keys.toList()..sort())
          if (name.startsWith("cvn_") && name.endsWith(".json")) name.substring(4, name.length - 5),
      ];
}

/// Fields that hold localized text (CE-01, data schema §5.1).
const _localizedFields = {
  "chapter", "title", "text", "caption", "transcript", "default_value", "notification_text", "summary", "name", //
  "bio", "status",
};

/// [json] with every localized text object replaced by its text in [locale], falling back to [source], the way
/// the engine shows it. Lets the core linter read a multi-language story one language at a time.
Object? flattenLocale(Object? json, String locale, String source) {
  if (json is List) return [for (final item in json) flattenLocale(item, locale, source)];
  if (json is! Map) return json;
  return <String, dynamic>{
    for (final MapEntry(:key, :value) in json.entries)
      key as String: _localizedFields.contains(key) && value is Map
          ? (value[locale] ?? value[source] ?? value.values.firstOrNull)
          : flattenLocale(value, locale, source),
  };
}

/// Runs cerita_core's `StoryLinter` (authoring tools spec §1) on the compiled story, once per locale, and maps
/// each issue back to the script line its item came from.
Future<Diagnostics> lintCompiled(StoryProject project, Map<String, String> compiled) async {
  final config = project.config;
  final decoded = {for (final MapEntry(:key, :value) in compiled.entries) key: jsonDecode(value)};
  final files = project.assetFiles;
  final diagnostics = Diagnostics();
  final seen = <String>{};
  for (final locale in config.locales) {
    final loader = CompiledStoryLoader({
      for (final MapEntry(:key, :value) in decoded.entries) key: flattenLocale(value, locale, config.sourceLocale),
    });
    final linter = core.StoryLinter(
      loader,
      config: const core.LoaderConfig(storyDir: ".", musicDir: "music", spritesDir: "sprites", bgDir: "bg", mediaDir: "media"),
      assetExists: files == null ? null : (path) => _assetExists(project, files, path),
    );
    for (final issue in await linter.lint()) {
      final id = [issue.severity, issue.conversationKey, issue.itemIndex, issue.part, issue.message].join("|");
      if (!seen.add(id)) continue;
      final span = _locate(project, issue);
      issue.isError ? diagnostics.error(span, issue.message) : diagnostics.warning(span, issue.message);
    }
  }
  return diagnostics;
}

/// Whether [path] (relative to the asset folder, or under `asset_prefix`) exists. The core linter also tries the
/// per-locale files of voice clips and voice notes (CE-01, data schema §7.4).
bool _assetExists(StoryProject project, Set<String> files, String path) {
  final prefix = project.config.assetPrefix;
  return files.contains(path.startsWith(prefix) ? path.substring(prefix.length) : path);
}

/// The script line of a core issue: the item it's about, the scene for scene-level issues, or the profile for
/// `profiles.json` issues.
SourceSpan? _locate(StoryProject project, core.LintIssue issue) {
  final key = issue.conversationKey;
  if (key == null) return _locateProfile(project.cast, issue.message);
  final conversation = project.conversationsByKey[key];
  if (conversation == null) return null;
  final index = issue.itemIndex;
  if (index != null && index < conversation.items.length) {
    final item = conversation.items[index];
    return _locatePart(item, issue.path) ?? item.span;
  }
  final aboutScene = issue.message.contains(" file '") || issue.message.contains("CHAT") || issue.message.contains("thread");
  return aboutScene ? conversation.scene?.span ?? conversation.span : conversation.span;
}

SourceSpan _locateProfile(Cast cast, String message) {
  final file = RegExp(r"'([^']+)'").firstMatch(message)?.group(1)?.split("/").last;
  for (final profile in cast.profiles.values) {
    for (var i = 0; i < profile.sprites.length; i++) {
      if (profile.sprites[i] == file) return profile.spriteSpans[i];
    }
    if (file != null && profile.avatar?.split("/").last == file) return profile.avatarSpan ?? profile.span;
  }
  return const SourceSpan(Cast.fileName, 1);
}

/// The line of the part of [item] an issue names (`LintIssue.path`): an option, a branch route or its fallback, an
/// effect or a stage action. The compiler writes them in script order, so JSON indexes match. Null for the item.
SourceSpan? _locatePart(ItemNode item, List<Object> path) {
  SourceSpan? effect(List<EffectNode> effects, List<Object> rest) => switch (rest) {
        ["effects", final int at, ...] when at < effects.length => effects[at].span,
        _ => null,
      };
  return switch ((item, path)) {
    (ChoiceItem(:final options), ["choices", final int at, "target", ...]) when at < options.length =>
      options[at].target?.span ?? options[at].span,
    (ChoiceItem(:final options), ["choices", final int at, ...final rest]) when at < options.length =>
      effect(options[at].effects, rest) ?? options[at].span,
    (BranchItem(:final routes), ["branches", final int at, ...]) when at < routes.length => routes[at].span,
    (BranchItem(:final fallback?), ["fallback_target", ...]) => fallback.span,
    (StageItem(:final actions), ["actions", final int at, ...]) when at < actions.length => actions[at].span,
    (_, ["effects", ...]) => effect(item.effects, path),
    _ => null,
  };
}
