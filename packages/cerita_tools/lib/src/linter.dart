import 'assets.dart';
import 'config.dart';
import 'diagnostics.dart';
import 'expression.dart';
import 'flow.dart';
import 'model.dart';
import 'project.dart';

/// Checks a story for everything that would break a playthrough (spec §3.1). Every problem is reported.
///
/// Every check is an error, except missing translations: warnings while drafting, errors when [release] is set.
Diagnostics lintStory(StoryProject project, {bool release = false}) {
  final diagnostics = Diagnostics()..addAll(project.diagnostics);
  _Linter(project, diagnostics, release).run();
  return diagnostics;
}

class _Linter {
  final StoryProject project;
  final Diagnostics diagnostics;
  final bool release;

  _Linter(this.project, this.diagnostics, this.release);

  StoryConfig get config => project.config;

  void run() {
    _structure();
    _references();
    _assets();
    _translations();
    _flow();
    _names();
    // Clue checks (CE-05) go here once clues have a syntax: declared but never found, used but not declared.
  }

  void _error(SourceSpan? span, String message) => diagnostics.error(span, message);

  /* Structure */

  void _structure() {
    final seen = <String, ConversationNode>{};
    for (final conversation in project.conversations) {
      final previous = seen[conversation.key];
      if (previous != null) {
        _error(conversation.span, "Conversation '${conversation.key}' is also declared at ${previous.span}");
      } else {
        seen[conversation.key] = conversation;
      }

      final labels = <String>{};
      for (final item in conversation.items) {
        final label = item.label;
        if (label != null && !labels.add(label)) _error(item.span, "Duplicate label '$label' in '${conversation.key}'");
      }

      final scene = conversation.scene;
      if (scene != null && scene.mode != "VN") {
        final channel = scene.channel;
        final channels = project.channels;
        if (channel == null) {
          _error(scene.span, "A ${scene.mode} scene needs channel=");
        } else if (channels != null && !channels.any((c) => c.id == channel)) {
          _error(scene.span, "Unknown chat thread '$channel'. Add it to channels.yaml");
        }
      }
    }
    if (project.conversations.isNotEmpty && !seen.containsKey(ConversationNode.indexKey)) {
      _error(null, "No 'index' conversation. The story starts at '@conversation index'");
    }
  }

  /* References */

  void _references() {
    final keys = project.conversationsByKey;
    void target(TargetRef? ref) {
      if (ref != null && !keys.containsKey(ref.key)) _error(ref.span, "Target '${ref.key}' doesn't exist");
    }

    void profile(ProfileRef? ref) {
      if (ref != null) project.resolveProfile(ref, diagnostics);
    }

    for (final channel in project.channels ?? const []) {
      for (var i = 0; i < channel.members.length; i++) {
        final member = channel.members[i];
        if (member != ProfileRef.player && project.cast[member] == null) {
          _error(channel.memberSpans[i], "Unknown character '$member'");
        }
      }
    }

    for (final conversation in project.conversations) {
      for (final item in conversation.items) {
        switch (item) {
          case LineItem():
            profile(item.speaker);
          case MediaItem():
            profile(item.by);
          case ChoiceItem():
            profile(item.by);
            for (final option in item.options) {
              target(option.target);
            }
          case InputItem():
            profile(item.by);
          case BranchItem():
            for (final route in item.routes) {
              target(route.target);
            }
            target(item.fallback);
          default:
            break;
        }
      }
    }
  }

  /* Assets */

  void _assets() {
    final files = project.assetFiles;
    if (files == null) {
      final reason = project.assetsError;
      if (reason != null) {
        _error(const SourceSpan(StoryConfig.fileName, 1), reason);
      } else if (release) {
        _error(null, "Release checks need the asset folder: set 'assets' in cerita.yaml or pass --assets");
      } else {
        diagnostics.note(null, "Asset checks skipped: set 'assets' in cerita.yaml or pass --assets");
      }
      return;
    }
    for (final ref in collectAssetRefs(project)) {
      if (!files.contains(ref.path)) _error(ref.span, "Missing ${ref.kind.replaceAll("_", " ")} file '${ref.path}'");
    }
  }

  /* Translations */

  void _translations() {
    if (!config.isMultiLocale) return;
    void check(Localized? text) {
      if (text == null || text.isPlain) return;
      for (final locale in config.locales) {
        if (text.values.containsKey(locale)) continue;
        final message = "Missing '$locale' text";
        release ? _error(text.span, message) : diagnostics.warning(text.span, message);
      }
    }

    void checkFields(TextHolder holder) {
      holder.texts.forEach((field, text) {
        if (field != "tts") check(text);
      });
    }

    for (final profile in project.cast.profiles.values) {
      check(profile.name);
      check(profile.handle);
      check(profile.bio);
    }
    for (final channel in project.channels ?? const []) {
      check(channel.name);
      check(channel.status);
    }
    for (final conversation in project.conversations) {
      check(conversation.chapter);
      check(conversation.title);
      for (final item in conversation.items) {
        checkFields(item);
        if (item is InputItem) check(item.defaultValue);
        if (item is ChoiceItem) item.options.forEach(checkFields);
      }
    }
  }

  /* Flow */

  void _flow() {
    final graph = FlowGraph(project.conversationsByKey.values.toList());
    final start = graph.start(ConversationNode.indexKey);
    if (start == null) return;
    final reachable = graph.reachableFrom(start);
    final stops = <ConversationNode>{};
    for (var node = 0; node < graph.length; node++) {
      final conversation = graph.conversationOf(node);
      final item = graph.itemAt(node);
      if (node == graph.start(conversation.key) && !reachable.contains(node)) {
        _error(conversation.span, "Conversation '${conversation.key}' can't be reached from index");
      }
      if (!reachable.contains(node) || !reachable.contains(graph.start(conversation.key))) continue;
      if (item == null && stops.add(conversation)) {
        final last = conversation.items.lastOrNull;
        _error(
          last?.span ?? conversation.span,
          "The story stops here: '${conversation.key}' can run out of items without an ending or a jump",
        );
      }
    }
    for (var node = 0; node < graph.length; node++) {
      final item = graph.itemAt(node);
      final conversation = graph.conversationOf(node);
      if (item is EndingItem && !reachable.contains(node) && reachable.contains(graph.start(conversation.key))) {
        _error(item.span, "Ending '${item.endingId}' can't be reached");
      }
    }
  }

  /* Variables, memory and conditions */

  void _names() {
    final sets = <String>{};
    final remembered = <String>{};
    final endings = <String>{};
    final reads = <(String, SourceSpan)>[];

    void effects(List<EffectNode> list) {
      for (final effect in list) {
        (effect.isRemember ? remembered : sets).add(effect.variable);
      }
    }

    void condition(String? source, SourceSpan span) {
      if (source == null) return;
      final info = ConditionInfo.analyze(source);
      if (!info.isValid) return _error(span, "Invalid condition '$source': ${info.error}");
      for (final name in info.names) {
        reads.add((name, span));
      }
    }

    void texts(TextHolder holder) {
      for (final text in holder.texts.values) {
        text.values.forEach((locale, value) {
          for (final name in interpolatedNames(value)) {
            reads.add((name, text.spans[locale] ?? text.span));
          }
        });
      }
    }

    for (final conversation in project.conversations) {
      for (final item in conversation.items) {
        effects(item.effects);
        condition(item.condition, item.span);
        texts(item);
        switch (item) {
          case ChoiceItem():
            if (item.variable != null) sets.add(item.variable!);
            for (final option in item.options) {
              effects(option.effects);
              condition(option.condition, option.span);
              texts(option);
            }
          case InputItem():
            sets.add(item.variable);
          case BranchItem():
            for (final route in item.routes) {
              condition(route.condition, route.span);
            }
          case EndingItem():
            endings.add(item.endingId);
          default:
            break;
        }
      }
    }

    for (final (name, span) in reads) {
      if (!name.contains(".")) {
        if (!sets.contains(name)) _error(span, "Variable '$name' is read but never set");
        continue;
      }
      final parts = name.split(".");
      final (namespace, key) = (parts.take(2).join("."), parts.skip(2).join("."));
      switch (namespace) {
        case "meta.ending" when parts.length == 3:
          if (!endings.contains(key)) _error(span, "Unknown ending '$key' in '$name'");
        case "meta.flag" when parts.length == 3:
          if (!remembered.contains(key)) _error(span, "Memory flag '$key' is read but no 'remember $key' sets it");
        default:
          _error(span, "Unknown name '$name'. Dotted names are meta.ending.<id> and meta.flag.<name>");
      }
    }
  }
}
