import 'dart:convert';

import 'cast.dart';
import 'diagnostics.dart';
import 'model.dart';
import 'project.dart';

class CompileResult {
  /// Output file name to JSON text, sorted by file name.
  final Map<String, String> files;
  final Diagnostics diagnostics;

  const CompileResult(this.files, this.diagnostics);

  bool get ok => !diagnostics.hasErrors;
}

/// Compiles a story into the engine's JSON files (spec §2.7).
///
/// Fails, with no files, on load and syntax errors and on speakers or expressions that don't exist, since those
/// can't be written as engine JSON. The output depends only on the sources: keys are written in a fixed order,
/// so compiling an unchanged story twice gives identical files.
CompileResult compileStory(StoryProject project) {
  final diagnostics = Diagnostics()..addAll(project.diagnostics);
  final compiler = _Compiler(project, diagnostics);
  final files = compiler.run();
  return CompileResult(diagnostics.hasErrors ? const {} : files, diagnostics);
}

String encodeJson(Object json) => "${const JsonEncoder.withIndent("  ").convert(json)}\n";

class _Compiler {
  final StoryProject project;
  final Diagnostics diagnostics;

  _Compiler(this.project, this.diagnostics);

  Map<String, String> run() {
    final files = <String, String>{};
    final seen = <String, ConversationNode>{};
    for (final conversation in project.conversations) {
      final previous = seen[conversation.key];
      if (previous != null) {
        diagnostics.error(conversation.span, "Conversation '${conversation.key}' is also declared at ${previous.span}");
        continue;
      }
      seen[conversation.key] = conversation;
      files[conversation.fileName] = encodeJson(_conversation(conversation));
    }
    files["profiles.json"] = encodeJson(_profiles());
    final channels = project.channels;
    if (channels != null) files["channels.json"] = encodeJson(_channels(channels));
    return Map.fromEntries(files.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  /* Values */

  String get _source => project.config.sourceLocale;

  Object? _text(Localized? text) {
    if (text == null || text.values.isEmpty) return null;
    if (text.isPlain) return text.values.values.first;
    final config = project.config;
    if (!config.isMultiLocale) return text.textFor(_source, _source);
    return {
      for (final locale in config.locales)
        if (text.values.containsKey(locale)) locale: text.values[locale],
    };
  }

  Object? _asset(LocalizedAsset? asset) {
    if (asset == null) return null;
    final config = project.config;
    final resolved = asset.resolve(config.locales, _source);
    if (!config.isMultiLocale) return resolved.values.firstOrNull ?? asset.shared;
    if (!asset.isPerLocale) return asset.shared;
    return resolved;
  }

  String? _profile(ProfileRef? ref) => ref == null ? null : project.resolveProfile(ref, diagnostics);

  /// Adds [value] under [key] unless it's `null`.
  void _put(Map<String, Object?> json, String key, Object? value) {
    if (value != null) json[key] = value;
  }

  List<Map<String, Object?>>? _effects(List<EffectNode> effects) {
    if (effects.isEmpty) return null;
    return [
      for (final effect in effects)
        {
          "variable": effect.variable,
          "op": effect.op,
          if (effect.hasValue) "value": effect.value,
        },
    ];
  }

  /* Files */

  Map<String, Object?> _conversation(ConversationNode conversation) {
    final json = <String, Object?>{"conversation_id": conversation.conversationId ?? "cvn_${conversation.key}"};
    _put(json, "chapter", _text(conversation.chapter));
    _put(json, "title", _text(conversation.title));
    if (conversation.checkpoint) json["checkpoint"] = true;
    final scene = conversation.scene;
    if (scene != null) {
      final sceneJson = <String, Object?>{"mode": scene.mode};
      _put(sceneJson, "channel_id", scene.channel);
      _put(sceneJson, "day", scene.day);
      _put(sceneJson, "time", scene.time);
      _put(sceneJson, "background", scene.background);
      _put(sceneJson, "music", scene.music);
      json["scene"] = sceneJson;
    }
    json["conversations"] = [for (final item in conversation.items) _item(item)];
    return json;
  }

  Map<String, Object?> _item(ItemNode item) {
    final json = <String, Object?>{"type": item.type};
    _put(json, "id", item.label);
    _put(json, "condition", item.condition);
    switch (item) {
      case LineItem():
        _put(json, "text", _text(item.texts["text"]));
        _put(json, "profile", _profile(item.speaker));
        _put(json, "position", item.position);
        _put(json, "typing_delay_ms", item.typingMs);
        _put(json, "sfx", item.sfx);
        _put(json, "voice", _asset(item.voice));
      case NarrationItem():
        _put(json, "style", item.style);
        _put(json, "text", _text(item.texts["text"]));
        _put(json, "sfx", item.sfx);
      case MediaItem():
        json["media_type"] = item.mediaType;
        json["uri"] = _asset(item.uri);
        _put(json, "caption", _text(item.texts["caption"]));
        _put(json, "transcript", _text(item.texts["transcript"]));
        _put(json, "profile", _profile(item.by));
        _put(json, "unlock_id", item.unlock);
        _put(json, "typing_delay_ms", item.typingMs);
        _put(json, "sfx", item.sfx);
      case ChoiceItem():
        _put(json, "text", _text(item.texts["text"]));
        _put(json, "variable", item.variable);
        _put(json, "profile", _profile(item.by));
        _put(json, "timeout_ms", item.timeoutMs);
        final defaultIndex = item.options.indexWhere((option) => option.isDefault);
        if (defaultIndex >= 0) json["default_choice"] = defaultIndex;
        json["choices"] = [for (final option in item.options) _option(option)];
      case InputItem():
        _put(json, "text", _text(item.texts["text"]));
        json["variable"] = item.variable;
        _put(json, "default_value", _text(item.defaultValue));
        _put(json, "profile", _profile(item.by));
      case WaitItem():
        json["duration_ms"] = item.durationMs;
        _put(json, "notification_text", _text(item.texts["notification_text"]));
      case BranchItem():
        if (item.routes.isNotEmpty) {
          json["branches"] = [
            for (final route in item.routes) {"condition": route.condition, "target": route.target.key},
          ];
        }
        _put(json, "fallback_target", item.fallback?.key);
      case EndingItem():
        json["ending_id"] = item.endingId;
        _put(json, "title", _text(item.texts["title"]));
        json["category"] = item.category;
        _put(json, "summary", _text(item.texts["summary"]));
    }
    _put(json, "effects", _effects(item.effects));
    return json;
  }

  Map<String, Object?> _option(OptionNode option) {
    final json = <String, Object?>{"text": _text(option.texts["text"])};
    if (option.hasValue) json["value"] = option.value;
    _put(json, "condition", option.condition);
    _put(json, "effects", _effects(option.effects));
    _put(json, "target", option.target?.key);
    return json;
  }

  Map<String, Object?> _profiles() => {
        "profiles": [
          for (final profile in project.cast.profiles.values)
            {
              "id": profile.id,
              "name": _text(profile.name),
              if (profile.handle != null) "handle": _text(profile.handle),
              if (profile.bio != null) "bio": _text(profile.bio),
              if (profile.avatar != null) "avatar": profile.avatar,
              if (profile.sprites.isNotEmpty) "sprites": profile.sprites,
            },
        ],
      };

  Map<String, Object?> _channels(List<ChannelDef> channels) => {
        "channels": [
          for (final channel in channels)
            {
              "id": channel.id,
              "name": _text(channel.name),
              if (channel.avatar != null) "avatar": channel.avatar,
              if (channel.status != null) "status": _text(channel.status),
              if (channel.members.isNotEmpty)
                "members": [
                  for (var i = 0; i < channel.members.length; i++) _member(channel.members[i], channel.memberSpans[i]),
                ],
            },
        ],
      };

  String _member(String key, SourceSpan span) {
    final profile = project.cast[key];
    if (profile == null) diagnostics.error(span, "Unknown character '$key'");
    return profile?.id ?? key;
  }
}
