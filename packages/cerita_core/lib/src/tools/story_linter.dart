import '../data/conversation.dart';
import '../data/effect.dart';
import '../data/items/base.dart';
import '../data/items/branch.dart';
import '../data/items/choice.dart';
import '../data/items/ending.dart';
import '../data/items/flow.dart';
import '../data/items/input.dart';
import '../data/items/media.dart';
import '../data/items/narration.dart';
import '../data/items/profile_info.dart';
import '../data/items/stage.dart';
import '../data/items/text.dart';
import '../data/channel.dart';
import '../data/profile.dart';
import '../data/scene.dart';
import '../loader.dart';
import '../state/story_state.dart';
import '../utils/condition_evaluator.dart';
import '../utils/text_markup.dart';
import '../utils/var_replacer.dart';
import 'story_graph.dart';

enum LintSeverity { error, warning }

class LintIssue {
  final LintSeverity severity;

  /// Conversation key, see [Conversation.key]. Null for `profiles.json`.
  final String? conversationKey;
  final int? itemIndex;
  final String message;

  const LintIssue(this.severity, this.conversationKey, this.itemIndex, this.message);

  bool get isError => severity == LintSeverity.error;

  /// The file the issue is in.
  String get file => switch (conversationKey) {
        null => "profiles.json",
        Conversation.indexKey => "index.json",
        final key => "cvn_$key.json",
      };

  @override
  String toString() =>
      "${severity.name.padRight(7)} ${[file, if (itemIndex != null) "#$itemIndex"].join(" ")}  $message";
}

/// Finds mistakes in a story before a player does: broken targets, unknown characters and sprites,
/// bad expressions, unknown text tags, unused or unset variables, unreachable conversations and,
/// with [assetExists], missing files. See the authoring tools spec §1.
class StoryLinter {
  final EngineLoader loader;
  final LoaderConfig config;

  /// Whether a file (a path built by [config]) exists. Null skips the file checks.
  final bool Function(String path)? assetExists;

  const StoryLinter(this.loader, {this.config = const LoaderConfig(), this.assetExists});

  /// Text fields that take `{{VAR}}` and text tags.
  static const _textKeys = {"text", "caption", "transcript", "title", "summary", "notification_text", "default_value"};

  /// Variables the engine reads by itself: the player's name.
  static const _engineReads = {"NAME"};

  Future<List<LintIssue>> lint() async {
    final issues = <LintIssue>[];
    void error(String? key, int? index, String message) => issues.add(LintIssue(LintSeverity.error, key, index, message));
    void warn(String? key, int? index, String message) => issues.add(LintIssue(LintSeverity.warning, key, index, message));

    var profiles = const ProfileData([]);
    var channels = const <Channel>[];
    var profilesLoaded = false;
    try {
      final package = await loader.initialLoad();
      profiles = package.profiles;
      channels = package.channels;
      profilesLoaded = true;
    } catch (e) {
      error(Conversation.indexKey, null, "Can't load the story: $e");
    }

    final conversations = <Conversation>[];
    final broken = <String>{};
    for (final key in await loader.listConversationKeys()) {
      try {
        conversations.add(await loader.loadConversation(key));
      } catch (e) {
        broken.add(key);
        if (!(key == Conversation.indexKey && !profilesLoaded)) error(key, null, "Can't load: $e");
      }
    }
    final byKey = {for (final conversation in conversations) conversation.key: conversation};

    void asset(String? key, int? index, String? name, String Function(String) path, String what) {
      final exists = assetExists;
      if (exists == null || name == null) return;
      if (!exists(path(name))) error(key, index, "Missing $what file '${path(name)}'");
    }

    // Characters and their sprites.
    for (final profile in profiles.profiles) {
      for (final sprite in profile.sprites) {
        asset(null, null, sprite, config.sprite, "sprite");
      }
      asset(null, null, profile.avatar, config.avatar, "avatar");
    }

    void character(String key, int index, ProfileInfo? info) {
      if (info == null || info.isPlayer || !profilesLoaded) return;
      final profile = profiles.byId(info.id);
      if (profile == null) {
        error(key, index, "Unknown character '${info.id}'");
      } else if (profile.sprites.isNotEmpty && info.spriteIndex >= profile.sprites.length) {
        error(key, index, "${profile.name} has no sprite ${info.spriteIndex} (${profile.sprites.length} sprites)");
      }
    }

    final reads = <String, (String, int)>{};
    final sets = <String, (String, int)>{};
    final endingIds = <String>{};

    void expression(String key, int index, String? source) {
      if (source == null || source.trim().isEmpty) return;
      final problem = ConditionEvaluator.syntaxError(source);
      if (problem != null) error(key, index, "Bad expression: $problem");
      for (final variable in ConditionEvaluator.variablesOf(source)) {
        reads.putIfAbsent(variable, () => (key, index));
      }
    }

    void effects(String key, int index, List<Effect> effects) {
      for (final effect in effects) {
        final remembers = effect.op == EffectOp.metaSet;
        if (!remembers && StoryState.isMeta(effect.variable)) {
          error(key, index, "'${effect.variable}' is read-only. Remember facts with the meta_set op");
        }
        // A remembered fact is read back as meta.flag.<name>.
        final variable = remembers ? "${StoryState.flagPrefix}${effect.variable}" : effect.variable;
        sets.putIfAbsent(variable, () => (key, index));
        expression(key, index, effect.expr);
      }
    }

    void text(String key, int index, Map<String, dynamic> json) {
      for (final MapEntry(key: field, :value) in json.entries) {
        if (!_textKeys.contains(field) || value is! String) continue;
        for (final match in variablePattern.allMatches(value)) {
          reads.putIfAbsent(match.group(1)!, () => (key, index));
        }
        // `{{` is an escaped `{`, written on purpose.
        final shown = TextMarkup.plain(value.replaceAll(variablePattern, "").replaceAll("{{", ""));
        final unknown = RegExp(r"\{/?[a-z]+(=[^{}]*)?\}").firstMatch(shown);
        if (unknown != null) warn(key, index, "Unknown text tag '${unknown.group(0)}'");
      }
    }

    void target(StoryLink link) {
      final conversation = byKey[link.targetKey];
      // Already reported as a file that fails to load.
      if (broken.contains(link.targetKey)) return;
      if (conversation == null) {
        error(link.from, link.itemIndex, "Target '${link.target}' doesn't exist");
        return;
      }
      final label = link.targetLabel;
      if (label != null && !conversation.conversations.any((item) => item.id == label)) {
        error(link.from, link.itemIndex, "Target '${link.target}' has no item with id '$label'");
      }
    }

    for (final conversation in conversations) {
      final key = conversation.key;
      final scene = conversation.scene;
      if (conversation.hasScene) {
        asset(key, null, scene.background, config.bg, "background");
        asset(key, null, scene.music, config.music, "music");
        asset(key, null, scene.ambience, config.music, "ambience");
        if (scene.mode == SceneMode.chat) {
          if (scene.channelId == null) {
            error(key, null, "CHAT scene without a channel_id");
          } else if (channels.isNotEmpty && !channels.any((channel) => channel.id == scene.channelId)) {
            warn(key, null, "Chat thread '${scene.channelId}' isn't in channels.json");
          }
        }
      }

      final ids = <String>{};
      for (final (index, item) in conversation.conversations.indexed) {
        final id = item.id;
        if (id != null && !ids.add(id)) error(key, index, "Duplicate id '$id'");
        if (item is EndingItemType) endingIds.add(item.endingId);
        expression(key, index, item.condition);
        effects(key, index, item.effects);
        text(key, index, item.json);
        character(key, index, item.getProfileInfo());

        switch (item) {
          case TextItemType(:final sfx, :final voice):
            asset(key, index, sfx, config.music, "sound");
            asset(key, index, voice, config.music, "voice");
          case NarrationItemType(:final sfx):
            asset(key, index, sfx, config.music, "sound");
          case MediaItemType(:final sfx):
            asset(key, index, sfx, config.music, "sound");
            asset(key, index, item.uri, (_) => config.mediaPath(item), "media");
          case ChoiceItemType(:final choices, :final variable, :final defaultChoice):
            if (variable != null) sets.putIfAbsent(variable, () => (key, index));
            if (choices.isEmpty) error(key, index, "CHOICE without options");
            if (defaultChoice != null && (defaultChoice < 0 || defaultChoice >= choices.length)) {
              error(key, index, "default_choice $defaultChoice isn't one of the ${choices.length} options");
            }
            for (final (choiceIndex, choice) in choices.indexed) {
              expression(key, index, choice.condition);
              effects(key, index, choice.effects);
              final raw = (item.json["choices"] as List)[choiceIndex] as Map;
              text(key, index, Map<String, dynamic>.from(raw));
            }
          case InputItemType(:final variable):
            sets.putIfAbsent(variable, () => (key, index));
          case BranchItemType(:final branches):
            for (final branch in branches) {
              expression(key, index, branch.condition);
            }
          case StageItemType(:final actions):
            for (final action in actions) {
              switch (action) {
                case ShowAction(:final profile):
                  character(key, index, profile);
                case BackgroundAction(:final image):
                  asset(key, index, image, config.bg, "background");
                case MusicAction(:final file) || AmbienceAction(:final file):
                  asset(key, index, file, config.music, "music");
                case SoundAction(:final file):
                  asset(key, index, file, config.music, "sound");
                default:
                  break;
              }
            }
        }
      }

      StoryLink.of(conversation).forEach(target);
      _deadItems(conversation, (index) => warn(key, index, "Never reached: it follows a JUMP or RETURN"));
    }

    final reachable = StoryGraph(conversations).reachable;
    for (final conversation in conversations) {
      if (!reachable.contains(conversation.key)) warn(conversation.key, null, "No target leads to this conversation");
    }

    for (final MapEntry(key: variable, value: (key, index)) in reads.entries) {
      if (variable.startsWith(StoryState.endingPrefix)) {
        final ending = variable.substring(StoryState.endingPrefix.length);
        if (!endingIds.contains(ending)) warn(key, index, "No ENDING has ending_id '$ending' (read as '$variable')");
      } else if (StoryState.isMeta(variable) && !variable.startsWith(StoryState.flagPrefix)) {
        error(key, index, "Unknown memory variable '$variable'. Use meta.ending.<ending_id> or meta.flag.<name>");
      } else if (!sets.containsKey(variable)) {
        warn(
          key,
          index,
          variable.startsWith(StoryState.flagPrefix)
              ? "Fact '$variable' is read but never remembered with meta_set"
              : "Variable '$variable' is read but never set",
        );
      }
    }
    for (final MapEntry(key: variable, value: (key, index)) in sets.entries) {
      if (!reads.containsKey(variable) && !_engineReads.contains(variable)) {
        warn(key, index, "Variable '$variable' is set but never read");
      }
    }

    return issues..sort(_order);
  }

  /// Reports the first item of each run that can't be reached: right after an unconditional JUMP,
  /// RETURN or BRANCH with a fallback, without an `id` a target could use.
  static void _deadItems(Conversation conversation, void Function(int index) report) {
    var dead = false;
    var reported = false;
    for (final (index, item) in conversation.conversations.indexed) {
      if (item.id != null) dead = false;
      if (dead) {
        if (!reported) report(index);
        reported = true;
        continue;
      }
      if (item.condition == null && _endsFlow(item)) {
        dead = true;
        reported = false;
      }
    }
  }

  static bool _endsFlow(ItemType item) => switch (item) {
        JumpItemType() || ReturnItemType() => true,
        BranchItemType(:final fallbackTarget) => fallbackTarget != null,
        _ => false,
      };

  static int _order(LintIssue a, LintIssue b) {
    final severity = a.severity.index.compareTo(b.severity.index);
    if (severity != 0) return severity;
    final file = a.file.compareTo(b.file);
    if (file != 0) return file;
    return (a.itemIndex ?? -1).compareTo(b.itemIndex ?? -1);
  }
}
