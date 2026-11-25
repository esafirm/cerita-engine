import 'dart:convert';

import 'cast.dart';
import 'config.dart';
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
///
/// With [partial], the files are returned even when there are errors, without the statements that failed to parse
/// and without unknown speakers. The linter uses this to run the JSON checks on a story that doesn't compile yet.
CompileResult compileStory(StoryProject project, {bool partial = false}) {
  final diagnostics = Diagnostics()..addAll(project.diagnostics);
  final compiler = _Compiler(project, diagnostics, partial: partial);
  final files = compiler.run();
  return CompileResult(diagnostics.hasErrors && !partial ? const {} : files, diagnostics);
}

String encodeJson(Object json) => "${const JsonEncoder.withIndent("  ").convert(json)}\n";

class _Compiler {
  final StoryProject project;
  final Diagnostics diagnostics;
  final bool partial;

  _Compiler(this.project, this.diagnostics, {required this.partial});

  /// Text the engine needs to load the item. A partial compile writes "" where it's missing (the parser has
  /// reported it), so the item still loads and keeps its place.
  Object? _required(Localized? text) => _text(text) ?? (partial ? "" : null);

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
    final clues = project.clues;
    if (clues != null) files["clues.json"] = encodeJson(_clues(clues));
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
          "expr": ?effect.expr,
        },
    ];
  }

  /* Files */

  Map<String, Object?> _conversation(ConversationNode conversation) {
    final json = <String, Object?>{"conversation_id": conversation.conversationId ?? "cvn_${conversation.key}"};
    if (conversation.key == ConversationNode.indexKey) _locales(json);
    _put(json, "chapter", _text(conversation.chapter));
    _put(json, "title", _text(conversation.title));
    if (conversation.checkpoint) json["checkpoint"] = true;
    final scene = conversation.scene;
    if (scene != null) {
      final sceneJson = <String, Object?>{"mode": scene.mode};
      _put(sceneJson, "channel_id", scene.channel);
      _put(sceneJson, "day", scene.day);
      _put(sceneJson, "time", scene.time);
      if (scene.hideStatus) {
        sceneJson["status"] = null;
      } else {
        _put(sceneJson, "status", _text(scene.status));
      }
      _put(sceneJson, "background", scene.background);
      _put(sceneJson, "music", scene.music);
      _put(sceneJson, "ambience", scene.ambience);
      _put(sceneJson, "ring", scene.ring);
      _put(sceneJson, "hangup", scene.hangUp?.key);
      _put(sceneJson, "stay", _text(scene.stay));
      _put(sceneJson, "textbox", scene.textbox);
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
        _put(json, "text", _required(item.texts["text"]));
        _put(json, "profile", _profile(item.speaker));
        _put(json, "position", item.position);
        if (item.offstage) json["offstage"] = true;
        _put(json, "typing_delay_ms", item.typingMs);
        _put(json, "sfx", item.sfx);
        _put(json, "voice", item.voice);
      case NarrationItem():
        _put(json, "style", item.style);
        _put(json, "text", _required(item.texts["text"]));
        _put(json, "sfx", item.sfx);
      case MediaItem():
        json["media_type"] = item.mediaType;
        json["uri"] = item.uri;
        _put(json, "caption", _text(item.texts["caption"]));
        _put(json, "transcript", _text(item.texts["transcript"]));
        _put(json, "profile", _profile(item.by));
        _put(json, "unlock_id", item.unlock);
        _put(json, "typing_delay_ms", item.typingMs);
        _put(json, "sfx", item.sfx);
      case EvidenceItem():
        json["source"] = "clues";
        _put(json, "text", _required(item.texts["text"]));
        _put(json, "variable", item.variable);
        _put(json, "profile", _profile(item.by));
        _put(json, "timeout_ms", item.timeoutMs);
        _put(json, "retries", item.retries);
        json["responses"] = [for (final response in item.responses) {"clue": response.clue, ..._outcome(response)}];
        for (final name in const ["retry", "fallback", "timeout"]) {
          if (item.outcome(name) case final outcome?) json[name] = _outcome(outcome);
        }
      case ChoiceItem():
        _put(json, "text", _required(item.texts["text"]));
        _put(json, "variable", item.variable);
        _put(json, "profile", _profile(item.by));
        _put(json, "timeout_ms", item.timeoutMs);
        if (item.silent) json["silent"] = true;
        final defaultIndex = item.options.indexWhere((option) => option.isDefault);
        if (defaultIndex >= 0) json["default_choice"] = defaultIndex;
        json["choices"] = [for (final option in item.options) _option(option)];
      case InputItem():
        _put(json, "text", _required(item.texts["text"]));
        json["variable"] = item.variable;
        _put(json, "default_value", _text(item.defaultValue));
        _put(json, "profile", _profile(item.by));
        _put(json, "keyboard", item.keyboard);
        _put(json, "min_length", item.minLength);
        _put(json, "max_length", item.maxLength);
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
      case JumpItem():
        json["target"] = item.target.key;
      case ReturnItem() || SetItem():
        break;
      case StageItem():
        _put(json, "wait_ms", item.waitMs);
        json["actions"] = [for (final action in item.actions) _stageAction(action)];
      case EndingItem():
        json["ending_id"] = item.endingId;
        _put(json, "title", _required(item.texts["title"]));
        json["category"] = item.category;
        _put(json, "summary", _text(item.texts["summary"]));
    }
    _put(json, "effects", _effects(item.effects));
    return json;
  }

  /// `source_locale` and `locales` go in index.json (CE-01, data schema §3). Like the engine's defaults, `locales`
  /// is left out for a single-language story, and `source_locale` too when it's `id`.
  void _locales(Map<String, Object?> json) {
    final config = project.config;
    if (config.isMultiLocale || config.sourceLocale != StoryConfig.defaultSourceLocale) {
      json["source_locale"] = config.sourceLocale;
    }
    if (config.isMultiLocale) json["locales"] = config.locales;
  }

  Map<String, Object?> _stageAction(StageAction action) {
    final json = <String, Object?>{"action": action.action};
    action.fields.forEach((key, value) {
      json[key] = switch (value) {
        ProfileRef() => _stageProfile(value, idOnly: action.idOnly),
        Localized() => _text(value),
        _ => value,
      };
    });
    return json;
  }

  String? _stageProfile(ProfileRef ref, {required bool idOnly}) {
    final resolved = project.resolveProfile(ref, diagnostics);
    return idOnly ? resolved?.split(":").first : resolved;
  }

  /// The effects and target of an evidence response or outcome.
  Map<String, Object?> _outcome(OptionNode option) => {
        "effects": ?_effects(option.effects),
        "target": ?option.target?.key,
      };

  Map<String, Object?> _option(OptionNode option) {
    final json = <String, Object?>{"text": _required(option.texts["text"])};
    if (option.hasValue) json["value"] = option.value;
    _put(json, "condition", option.condition);
    if (option.once) json["once"] = true;
    if (option.memoryMarker) json["memory_marker"] = true;
    if (option.silent) json["silent"] = true;
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
              if (profile.handle != null) "handle": profile.handle,
              if (profile.bio != null) "bio": _text(profile.bio),
              if (profile.avatar != null) "avatar": profile.avatar,
              if (profile.sprites.isNotEmpty) "sprites": profile.sprites,
              if (profile.height != null) "height": profile.height,
              if (profile.head case final head?) "head": {"top": head.top, "chin": head.chin},
            },
        ],
      };

  Map<String, Object?> _clues(ClueFile clues) => {
        if (clues.showCounts) "show_counts": true,
        "clues": [
          for (final clue in clues.clues)
            {
              "id": clue.id,
              "title": _required(clue.title),
              "description": ?_text(clue.description),
              "image": ?clue.image,
              if (clue.key) "key": true,
              "chapter": ?_text(clue.chapter),
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
              if (channel.owner != null) "owner": _member(channel.owner!, channel.ownerSpan!),
            },
        ],
      };

  String _member(String key, SourceSpan span) {
    final profile = project.cast[key];
    if (profile == null) diagnostics.error(span, "Unknown character '$key'");
    return profile?.id ?? key;
  }
}
