import '../data/conversation.dart';
import '../data/credits.dart';
import '../data/effect.dart';
import '../data/item_result.dart';
import '../data/items/base.dart';
import '../data/items/branch.dart';
import '../data/items/choice.dart';
import '../data/items/ending.dart';
import '../data/items/evidence.dart';
import '../data/items/flow.dart';
import '../data/items/input.dart';
import '../data/items/media.dart';
import '../data/items/narration.dart';
import '../data/items/profile_info.dart';
import '../data/items/stage.dart';
import '../data/items/text.dart';
import '../data/items/wait.dart';
import '../data/channel.dart';
import '../data/clue.dart';
import '../data/profile.dart';
import '../data/scene.dart';
import '../l10n/localized_text.dart';
import '../loader.dart';
import '../state/story_state.dart';
import '../utils/condition_evaluator.dart';
import '../utils/text_markup.dart';
import '../utils/var_replacer.dart';
import 'story_graph.dart';

enum LintSeverity { error, warning }

/// A scene as the linter tells them apart: its mode and chat thread.
typedef _SceneKey = (SceneMode, String?);

class LintIssue {
  final LintSeverity severity;

  /// Conversation key, see [Conversation.key]. Null for `profiles.json`.
  final String? conversationKey;
  final int? itemIndex;
  final String message;

  /// The file when it isn't a conversation or `profiles.json`, e.g. `clues.json`.
  final String? fileName;

  /// The part of the item the issue is about, as JSON keys and list indexes: `["choices", 2]` for the third
  /// option, `["choices", 2, "effects", 0]` for its first effect. Empty when it's about the whole item.
  final List<Object> path;

  const LintIssue(
    this.severity,
    this.conversationKey,
    this.itemIndex,
    this.message, {
    this.fileName,
    this.path = const [],
  });

  bool get isError => severity == LintSeverity.error;

  /// [path] as text, e.g. `choices[2].effects[0]`.
  String get part =>
      [for (final (index, step) in path.indexed) step is int ? "[$step]" : "${index > 0 ? "." : ""}$step"].join();

  /// The file the issue is in.
  String get file =>
      fileName ??
      switch (conversationKey) {
        null => "profiles.json",
        Conversation.indexKey => "index.json",
        final key => "cvn_$key.json",
      };

  @override
  String toString() {
    final where = [file, if (itemIndex != null) "#$itemIndex", if (path.isNotEmpty) part];
    return "${severity.name.padRight(7)} ${where.join(" ")}  $message";
  }
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

  static final _unknownTag = RegExp(r"\{/?[a-z]+(=[^{}]*)?\}");

  Future<List<LintIssue>> lint() async {
    final issues = <LintIssue>[];
    void error(String? key, int? index, String message, [List<Object> path = const []]) =>
        issues.add(LintIssue(LintSeverity.error, key, index, message, path: path));
    void warn(String? key, int? index, String message, [List<Object> path = const []]) =>
        issues.add(LintIssue(LintSeverity.warning, key, index, message, path: path));

    var profiles = const ProfileData([]);
    var channels = const <Channel>[];
    var clues = ClueCatalog.empty;
    var profilesLoaded = false;
    try {
      final package = await loader.initialLoad();
      profiles = package.profiles;
      channels = package.channels;
      clues = package.clues;
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
    final profilesById = {for (final profile in profiles.profiles) profile.id: profile};
    final channelIds = {for (final channel in channels) channel.id};
    final linksByKey = {for (final conversation in conversations) conversation.key: StoryLink.of(conversation).toList()};
    final idsByKey = {
      for (final conversation in conversations)
        conversation.key: {for (final item in conversation.conversations) ?item.id},
    };

    void asset(
      String? key,
      int? index,
      String? name,
      String Function(String) path,
      String what, [
      List<Object> at = const [],
    ]) {
      final exists = assetExists;
      if (exists == null || name == null) return;
      if (!exists(path(name))) error(key, index, "Missing $what file '${path(name)}'", at);
    }

    // A voice clip or voice note passes with its shared file or with one for every story locale, the files the
    // player tries (data schema §7.4).
    final locales = byKey[Conversation.indexKey]?.locales.supported ?? const [StoryLocales.defaultSource];
    void voice(String key, int index, String? name, String Function(String) path, String what) {
      final exists = assetExists;
      if (exists == null || name == null) return;
      if (locales.every((locale) => exists(path(localizedAssetName(name, locale))))) return;
      asset(key, index, name, path, what);
    }

    // Characters and their sprites.
    for (final profile in profiles.profiles) {
      for (final sprite in profile.sprites) {
        asset(null, null, sprite, config.sprite, "sprite");
      }
      asset(null, null, profile.avatar, config.avatar, "avatar");
    }

    // Chat threads name their contacts and owner by profile id.
    if (profilesLoaded) {
      for (final channel in channels) {
        final avatar = channel.avatar;
        if (avatar != null && assetExists != null && !assetExists!(config.avatar(avatar))) {
          issues.add(
            LintIssue(
              LintSeverity.error,
              null,
              null,
              "Missing avatar file '${config.avatar(avatar)}'",
              fileName: "channels.json",
            ),
          );
        }
        for (final id in [...channel.members, ?channel.owner]) {
          if (id != ProfileInfo.playerId && !profilesById.containsKey(id)) {
            issues.add(
              LintIssue(
                LintSeverity.error,
                null,
                null,
                "Thread '${channel.id}' names unknown character '$id'",
                fileName: "channels.json",
              ),
            );
          }
        }
      }
    }

    // Clues and their images.
    void clueError(String message) =>
        issues.add(LintIssue(LintSeverity.error, null, null, message, fileName: "clues.json"));
    void clueWarning(String message) =>
        issues.add(LintIssue(LintSeverity.warning, null, null, message, fileName: "clues.json"));
    final clueIds = <String>{};
    for (final clue in clues.clues) {
      if (!Clue.idPattern.hasMatch(clue.id)) clueError("Clue id '${clue.id}' can only use letters, digits and _");
      if (!clueIds.add(clue.id)) clueError("Duplicate clue id '${clue.id}'");
      final image = clue.image;
      if (image != null && assetExists != null && !assetExists!(config.media(image))) {
        clueError("Missing clue image file '${config.media(image)}'");
      }
    }

    void character(String key, int index, ProfileInfo? info, [List<Object> at = const []]) {
      if (info == null || info.isPlayer || !profilesLoaded) return;
      final profile = profilesById[info.id];
      if (profile == null) {
        error(key, index, "Unknown character '${info.id}'", at);
      } else if (profile.sprites.isNotEmpty && (info.spriteIndex < 0 || info.spriteIndex >= profile.sprites.length)) {
        error(key, index, "${profile.name} has no sprite ${info.spriteIndex} (${profile.sprites.length} sprites)", at);
      }
    }

    void characterId(String key, int index, String? id, [List<Object> at = const []]) {
      if (id == null || id == ProfileInfo.playerId || !profilesLoaded) return;
      if (!profilesById.containsKey(id)) error(key, index, "Unknown character '$id'", at);
    }

    void writeTarget(String key, int index, String variable, [List<Object> at = const []]) {
      if (StoryState.isMeta(variable)) {
        error(key, index, "'$variable' is read-only. Remember facts with the meta_set op", at);
      }
    }

    // Where each variable is first read and set: conversation, item and the part of the item.
    final reads = <String, (String, int, List<Object>)>{};
    final sets = <String, (String, int, List<Object>)>{};
    // Variables that name a CHOICE or evidence question. Nothing has to read them: they name the question for route
    // tests, the developer panel and saves, so they aren't reported as set but never read.
    final questionVariables = <String>{};
    final endingIds = <String>{};

    // Where each clue is awarded, and each evidence question with the clues it has a response for.
    final awards = <String, List<(String, int)>>{};
    final questions = <(String, int, Set<String>)>[];

    void expression(String key, int index, String? source, [List<Object> at = const []]) {
      if (source == null || source.trim().isEmpty) return;
      final problem = ConditionEvaluator.syntaxError(source);
      if (problem != null) error(key, index, "Bad expression: $problem", at);
      for (final variable in ConditionEvaluator.variablesOf(source)) {
        reads.putIfAbsent(variable, () => (key, index, at));
      }
    }

    void effects(String key, int index, List<Effect> effects, [List<Object> at = const []]) {
      for (final (effectIndex, effect) in effects.indexed) {
        final path = [...at, "effects", effectIndex];
        final remembers = effect.op == EffectOp.metaSet;
        if (!remembers && StoryState.isMeta(effect.variable)) {
          error(key, index, "'${effect.variable}' is read-only. Remember facts with the meta_set op", path);
        }
        // A remembered fact is read back as meta.flag.<name>.
        final variable = remembers ? "${StoryState.flagPrefix}${effect.variable}" : effect.variable;
        sets.putIfAbsent(variable, () => (key, index, path));
        if (Clue.idOf(variable) case final clue?) awards.putIfAbsent(clue, () => []).add((key, index));
        expression(key, index, effect.expr, path);
      }
    }

    void text(String key, int index, Map<String, dynamic> json, [List<Object> at = const []]) {
      for (final MapEntry(key: field, :value) in json.entries) {
        if (!_textKeys.contains(field)) continue;
        final warnedTags = <String>{};
        void check(String raw) {
          for (final match in variablePattern.allMatches(raw)) {
            reads.putIfAbsent(match.group(1)!, () => (key, index, at));
          }
          // `{{` is an escaped `{`, written on purpose.
          final shown = TextMarkup.plain(raw.replaceAll(variablePattern, "").replaceAll("{{", ""));
          final unknown = _unknownTag.firstMatch(shown);
          if (unknown != null && warnedTags.add(unknown.group(0)!)) {
            warn(key, index, "Unknown text tag '${unknown.group(0)}'", at);
          }
        }

        if (value is String) {
          check(value);
        } else if (value is Map) {
          for (final entry in value.values) {
            if (entry is String) check(entry);
          }
        }
      }
    }

    void target(StoryLink link) {
      final conversation = byKey[link.targetKey];
      // Already reported as a file that fails to load.
      if (broken.contains(link.targetKey)) return;
      if (conversation == null) {
        error(link.from, link.itemIndex, "Target '${link.target}' doesn't exist", link.path);
        return;
      }
      final label = link.targetLabel;
      if (label != null && !(idsByKey[link.targetKey]?.contains(label) ?? false)) {
        error(link.from, link.itemIndex, "Target '${link.target}' has no item with id '$label'", link.path);
      }
    }

    for (final conversation in conversations) {
      final key = conversation.key;
      final scene = conversation.scene;
      if (conversation.hasScene) {
        asset(key, null, scene.background, config.bg, "background");
        asset(key, null, scene.music, config.music, "music");
        asset(key, null, scene.ambience, config.music, "ambience");
        asset(key, null, scene.ring, config.music, "sound");
        if (scene.mode == SceneMode.chat) {
          if (scene.channelId == null) {
            error(key, null, "CHAT scene without a channel_id");
          } else if (channels.isNotEmpty && !channelIds.contains(scene.channelId)) {
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
          case TextItemType(:final sfx):
            asset(key, index, sfx, config.music, "sound");
            voice(key, index, item.voice, config.music, "voice");
          case NarrationItemType(:final sfx):
            asset(key, index, sfx, config.music, "sound");
          case MediaItemType(:final sfx, :final mediaType):
            asset(key, index, sfx, config.music, "sound");
            if (mediaType == MediaType.audio) {
              voice(key, index, item.uri, config.media, "media");
            } else {
              asset(key, index, item.uri, (_) => config.mediaPath(item), "media");
            }
          case EvidenceItemType(:final responses, :final variable, :final retries):
            if (variable != null) {
              writeTarget(key, index, variable);
              sets.putIfAbsent(variable, () => (key, index, const []));
              questionVariables.add(variable);
            }
            if (responses.isEmpty) error(key, index, "Evidence question without responses");
            if (item.json.containsKey("choices")) error(key, index, "An evidence question takes no choices");
            if (item.json.containsKey("default_choice")) {
              error(key, index, "An evidence question takes no default_choice. Use a timeout outcome");
            }
            if (retries < 0) error(key, index, "retries can't be negative");
            final answered = <String>{};
            for (final (responseIndex, response) in responses.indexed) {
              final at = ["responses", responseIndex];
              if (!answered.add(response.clue)) error(key, index, "Two responses for clue '${response.clue}'", at);
              if (!clueIds.contains(response.clue)) {
                error(key, index, "Clue '${response.clue}' isn't declared in clues.json", at);
              }
              effects(key, index, response.effects, at);
            }
            final outcomes = [("retry", item.retry), ("fallback", item.fallback), ("timeout", item.timeout)];
            for (final (name, outcome) in outcomes) {
              if (outcome != null) effects(key, index, outcome.effects, [name]);
            }
            questions.add((key, index, answered));
          case ChoiceItemType(:final choices, :final variable, :final defaultChoice):
            if (variable != null) {
              writeTarget(key, index, variable);
              sets.putIfAbsent(variable, () => (key, index, const []));
              questionVariables.add(variable);
            }
            if (choices.isEmpty) error(key, index, "CHOICE without options");
            if (defaultChoice != null && (defaultChoice < 0 || defaultChoice >= choices.length)) {
              error(key, index, "default_choice $defaultChoice isn't one of the ${choices.length} options");
            }
            for (final (choiceIndex, choice) in choices.indexed) {
              final at = ["choices", choiceIndex];
              expression(key, index, choice.condition, at);
              effects(key, index, choice.effects, at);
              final raw = (item.json["choices"] as List)[choiceIndex] as Map;
              text(key, index, Map<String, dynamic>.from(raw), at);
            }
          case InputItemType(:final variable):
            writeTarget(key, index, variable);
            sets.putIfAbsent(variable, () => (key, index, const []));
          case BranchItemType(:final branches):
            for (final (branchIndex, branch) in branches.indexed) {
              expression(key, index, branch.condition, ["branches", branchIndex]);
            }
          case StageItemType(:final actions):
            for (final (actionIndex, action) in actions.indexed) {
              final at = ["actions", actionIndex];
              switch (action) {
                case ShowAction(:final profile):
                  character(key, index, profile, at);
                case HideAction(:final profileId):
                  characterId(key, index, profileId, at);
                case MoveAction(:final profileId):
                  characterId(key, index, profileId, at);
                case BackgroundAction(:final image):
                  asset(key, index, image, config.bg, "background", at);
                case CgAction(:final image):
                  asset(key, index, image, config.bg, "cg", at);
                case MusicAction(:final file) || AmbienceAction(:final file):
                  asset(key, index, file, config.music, "music", at);
                case SoundAction(:final file):
                  asset(key, index, file, config.music, "sound", at);
                default:
                  break;
              }
            }
        }
      }

      linksByKey[key]!.forEach(target);
      _deadItems(conversation, (index) => warn(key, index, "Never reached: it follows a JUMP or RETURN"));
    }

    final scenes = _scenes(conversations);
    for (final conversation in conversations) {
      final key = conversation.key;
      final scene = scenes[key];
      if (scene == null || scene.$1 != SceneMode.chat) continue;
      _doubleReplies(
        conversation,
        scene,
        byKey,
        (index, option) => warn(
          key,
          index,
          "Option ${option + 1} is sent as the player's message and a player line follows it, so the message "
          "shows twice. Mark the option silent",
          ["choices", option],
        ),
      );
    }

    final graph = StoryGraph(conversations);
    final reachable = graph.reachable;
    for (final conversation in conversations) {
      if (!reachable.contains(conversation.key)) warn(conversation.key, null, "No target leads to this conversation");
    }
    _stops(graph, (key, index) {
      warn(key, index, "The story can stop here: no ENDING, JUMP, RETURN or BRANCH fallback after this item");
    });

    // In a story with clues, `clue_<x>` variables stand for clues. Declared ones are read by the board.
    bool isClue(String variable) => clues.isNotEmpty && Clue.idOf(variable) != null;
    final undeclared = <String>{};
    for (final MapEntry(key: variable, value: (key, index, at)) in [...reads.entries, ...sets.entries]) {
      final clue = Clue.idOf(variable);
      if (isClue(variable) && !clueIds.contains(clue) && undeclared.add(variable)) {
        error(key, index, "Clue '$clue' isn't declared in clues.json (used as '$variable')", at);
      }
    }
    for (final clue in clues.clues) {
      if (!awards.containsKey(clue.id)) {
        clueWarning("Clue '${clue.id}' is never awarded: no effect sets '${clue.variable}'");
      }
    }
    _checkAnswers(conversations, questions, awards, (key, index) {
      error(key, index, "No clue with a response can be found before this evidence question");
    });

    for (final MapEntry(key: variable, value: (key, index, at)) in reads.entries) {
      if (isClue(variable)) continue;
      if (variable.startsWith(StoryState.endingPrefix)) {
        final ending = variable.substring(StoryState.endingPrefix.length);
        if (!endingIds.contains(ending)) {
          warn(key, index, "No ENDING has ending_id '$ending' (read as '$variable')", at);
        }
      } else if (StoryState.isMeta(variable) && !variable.startsWith(StoryState.flagPrefix)) {
        error(key, index, "Unknown memory variable '$variable'. Use meta.ending.<ending_id> or meta.flag.<name>", at);
      } else if (!sets.containsKey(variable)) {
        warn(
          key,
          index,
          variable.startsWith(StoryState.flagPrefix)
              ? "Fact '$variable' is read but never remembered with meta_set"
              : "Variable '$variable' is read but never set",
          at,
        );
      }
    }
    for (final MapEntry(key: variable, value: (key, index, at)) in sets.entries) {
      if (!reads.containsKey(variable) &&
          !_engineReads.contains(variable) &&
          !isClue(variable) &&
          !questionVariables.contains(variable)) {
        warn(key, index, "Variable '$variable' is set but never read", at);
      }
    }

    await _checkCredits(
      endingIds,
      (message) => issues.add(LintIssue(LintSeverity.error, null, null, message, fileName: "credits.json")),
    );

    return issues..sort(_order);
  }

  /// `credits.json` must load, and the endings it rolls after must exist.
  Future<void> _checkCredits(Set<String> endingIds, void Function(String message) error) async {
    final Credits? credits;
    try {
      credits = await loader.loadCredits();
    } catch (e) {
      error("Can't load: $e");
      return;
    }
    for (final ending in credits?.rollAfter ?? const <String>{}) {
      if (!endingIds.contains(ending)) error("roll_after: no ENDING has ending_id '$ending'");
    }
  }

  /// Reports each evidence question in [questions] (conversation, item index, clues with a response) for which
  /// no such clue is awarded before it. "Before" is approximated from the story graph: earlier in the same
  /// conversation, in a conversation that can reach it, or in one those `CALL`. Conditions aren't followed.
  static void _checkAnswers(
    List<Conversation> conversations,
    List<(String, int, Set<String>)> questions,
    Map<String, List<(String, int)>> awards,
    void Function(String key, int index) report,
  ) {
    final into = <String, Set<String>>{};
    final calls = <String, Set<String>>{};
    final callsAt = <String, List<(int, String)>>{};
    for (final conversation in conversations) {
      for (final link in StoryLink.of(conversation)) {
        if (link.targetKey == conversation.key) continue;
        into.putIfAbsent(link.targetKey, () => {}).add(conversation.key);
        if (link.kind != LinkKind.call) continue;
        calls.putIfAbsent(conversation.key, () => {}).add(link.targetKey);
        callsAt.putIfAbsent(conversation.key, () => []).add((link.itemIndex!, link.targetKey));
      }
    }

    /// Conversations from which [key] can be reached, plus the ones they call and the ones [key] calls before
    /// item [index]. [key] itself only if it loops.
    Set<String> before(String key, int index) {
      final seen = <String>{};
      final queue = [...?into[key]];
      while (queue.isNotEmpty) {
        final next = queue.removeLast();
        if (seen.add(next)) queue.addAll(into[next] ?? const {});
      }
      final called = [
        for (final from in seen) ...?calls[from],
        for (final (at, target) in callsAt[key] ?? const <(int, String)>[])
          if (at < index) target,
      ];
      while (called.isNotEmpty) {
        final next = called.removeLast();
        if (seen.add(next)) called.addAll(calls[next] ?? const {});
      }
      return seen;
    }

    for (final (key, index, answered) in questions) {
      final earlier = before(key, index);
      final found = answered.any(
        (clue) => (awards[clue] ?? const []).any((award) {
          final (from, at) = award;
          return earlier.contains(from) || (from == key && at < index);
        }),
      );
      if (!found) report(key, index);
    }
  }

  /// Reports the last item of each conversation where the story can run out of items and end without an
  /// ending: one the story enters at the top level (from `index`, or through a target that isn't a `CALL`),
  /// with nothing after its last entry point that ends the story or leads on. Conditions aren't evaluated.
  static void _stops(StoryGraph graph, void Function(String key, int? index) report) {
    final byKey = {for (final conversation in graph.conversations) conversation.key: conversation};
    final labels = <String, Set<String>>{};
    for (final conversation in graph.conversations) {
      for (final link in StoryLink.of(conversation)) {
        if (link.targetLabel case final label?) labels.putIfAbsent(link.targetKey, () => {}).add(label);
      }
    }
    // Running out of items inside a CALL returns to the caller, so only top-level conversations can stop.
    final top = <String>{};
    final queue = [Conversation.indexKey];
    while (queue.isNotEmpty) {
      final key = queue.removeLast();
      final conversation = byKey[key];
      if (conversation == null || !top.add(key)) continue;
      for (final link in StoryLink.of(conversation)) {
        if (link.kind != LinkKind.call) queue.add(link.targetKey);
      }
    }
    for (final key in top) {
      final items = byKey[key]!.conversations;
      var entry = 0;
      for (final (index, item) in items.indexed) {
        if (labels[key]?.contains(item.id) ?? false) entry = index;
      }
      final leadsOn = [
        for (final (index, item) in items.indexed)
          if (index >= entry && item.condition == null && _leadsOn(item)) item,
      ];
      if (leadsOn.isEmpty) report(key, items.isEmpty ? null : items.length - 1);
    }
  }

  /// Whether the story never runs past [item]: it ends the story, jumps away or returns. A choice does when every
  /// option goes somewhere and one of them is always there.
  static bool _leadsOn(ItemType item) => switch (item) {
    EndingItemType() => true,
    // A response or outcome without a target continues after the question. `retry` asks it again.
    EvidenceItemType(:final responses, :final fallback, :final timeout) =>
      responses.every((response) => response.target != null) &&
          fallback?.target != null &&
          (timeout == null || timeout.target != null),
    ChoiceItemType(:final choices) =>
      choices.isNotEmpty &&
          choices.every((choice) => choice.target != null) &&
          choices.any((choice) => choice.condition == null && !choice.once),
    _ => _endsFlow(item),
  };

  /// The scene each conversation plays in, as its mode and chat thread. A conversation without a `scene` keeps
  /// the one it is entered from, so it gets the scene of every conversation whose targets lead to it (and the
  /// default VN scene if the story can start in it). Null when that isn't a single scene: entered from different
  /// scenes, or from nowhere. Coming back from a `CALL` into a scene isn't followed.
  static Map<String, _SceneKey?> _scenes(List<Conversation> conversations) {
    final into = <String, Set<String>>{};
    for (final conversation in conversations) {
      for (final link in StoryLink.of(conversation)) {
        if (link.targetKey != conversation.key) into.putIfAbsent(link.targetKey, () => {}).add(conversation.key);
      }
    }
    const _SceneKey start = (SceneMode.vn, null);
    final possible = <String, Set<_SceneKey>>{
      for (final conversation in conversations)
        conversation.key: {
          if (conversation.hasScene) (conversation.scene.mode, conversation.scene.channelId),
          if (!conversation.hasScene && conversation.key == Conversation.indexKey) start,
        },
    };
    for (var changed = true; changed;) {
      changed = false;
      for (final conversation in conversations.where((conversation) => !conversation.hasScene)) {
        final scenes = possible[conversation.key]!;
        for (final from in into[conversation.key] ?? const <String>{}) {
          for (final scene in possible[from] ?? const <_SceneKey>{}) {
            if (scenes.add(scene)) changed = true;
          }
        }
      }
    }
    return {for (final MapEntry(:key, :value) in possible.entries) key: value.length == 1 ? value.single : null};
  }

  /// In a chat, a picked option is sent as the player's message. Reports options after which the first item the
  /// player sees is a player line anyway, which would send the message twice. See [_playerLineFollows].
  static void _doubleReplies(
    Conversation conversation,
    _SceneKey scene,
    Map<String, Conversation> byKey,
    void Function(int index, int option) report,
  ) {
    for (final (index, item) in conversation.conversations.indexed) {
      if (item is! ChoiceItemType || item is EvidenceItemType) continue;
      for (final option in item.choices) {
        if (option.silent) continue;
        final known = <String, dynamic>{};
        _applyKnown(item.effects, known);
        final variable = item.variable;
        if (variable != null) {
          // An option without a `value` stores its text, which can't be known when it shows a variable.
          if (option.value == null && option.text.contains("{{")) {
            known.remove(variable);
          } else {
            known[variable] = ItemResult.choice(variable, option).value;
          }
        }
        _applyKnown(option.effects, known);
        if (_playerLineFollows(conversation, index + 1, option.target, scene, byKey, known)) {
          report(index, option.index);
        }
      }
    }
  }

  /// Whether the first item the player sees after an option is a player `TEXT` in the same chat thread. Starts at
  /// [index] in [conversation], or at the option's [target]. Walks past `SET`, `STAGE` and `WAIT` items (a
  /// `WAIT`'s notification isn't a chat message), items whose condition is false, and follows `JUMP`, `CALL`,
  /// `RETURN` and `BRANCH` into other conversations with no scene or the same chat scene.
  ///
  /// [known] holds the variables set by the pick: the choice variable and simple effects. Everything else is
  /// unknown, so a condition that reads it may or may not hold. The walk then stops without a report, so a line
  /// that only might play isn't reported.
  static bool _playerLineFollows(
    Conversation conversation,
    int index,
    String? target,
    _SceneKey scene,
    Map<String, Conversation> byKey,
    Map<String, dynamic> known,
  ) {
    var current = conversation;
    var at = index;
    final calls = <(Conversation, int)>[];

    bool go(String target) {
      final hash = target.indexOf("#");
      final key = hash < 0 ? target : target.substring(0, hash);
      final next = key.isEmpty ? current : byKey[key];
      // Another scene or thread: the line isn't sent next to the reply.
      if (next == null || (next.hasScene && (next.scene.mode, next.scene.channelId) != scene)) return false;
      final start = hash < 0 ? 0 : next.conversations.indexWhere((item) => item.id == target.substring(hash + 1));
      if (start < 0) return false;
      current = next;
      at = start;
      return true;
    }

    if (target != null && !go(target)) return false;
    final seen = <(String, int, int)>{};
    while (seen.add((current.key, at, calls.length))) {
      final items = current.conversations;
      if (at >= items.length) {
        if (calls.isEmpty) return false;
        (current, at) = calls.removeLast();
        continue;
      }
      final item = items[at];
      final plays = _holds(item.condition, known);
      if (plays == false) {
        at++;
        continue;
      }
      switch (item) {
        case SetItemType() || StageItemType() || WaitItemType():
          // Shown to nobody in a chat: only its effects matter.
          if (plays == null) {
            for (final effect in item.effects) {
              known.remove(_setsVariable(effect));
            }
          } else {
            _applyKnown(item.effects, known);
          }
          at++;
        case _ when plays == null:
          return false;
        case JumpItemType(:final target):
          _applyKnown(item.effects, known);
          if (!go(target)) return false;
        case CallItemType(:final target):
          _applyKnown(item.effects, known);
          if (calls.length > 50) return false;
          calls.add((current, at + 1));
          if (!go(target)) return false;
        case ReturnItemType():
          _applyKnown(item.effects, known);
          if (calls.isEmpty) return false;
          (current, at) = calls.removeLast();
        case BranchItemType(:final branches, :final fallbackTarget):
          String? next;
          for (final branch in branches) {
            final taken = _holds(branch.condition, known);
            if (taken == null) return false;
            if (taken) {
              next = branch.target;
              break;
            }
          }
          next ??= fallbackTarget;
          if (next == null) {
            at++;
          } else if (!go(next)) {
            return false;
          }
        case TextItemType():
          return item.getProfileInfo()?.isPlayer ?? false;
        default:
          return false;
      }
    }
    return false;
  }

  /// A call to `random()`, whose result can't be known.
  static final _random = RegExp(r"\brandom\s*\(");

  /// Whether [condition] holds with the [known] variables. Null when it reads anything else, uses `random()` or
  /// can't be evaluated.
  static bool? _holds(String? condition, Map<String, dynamic> known) {
    if (condition == null || condition.trim().isEmpty) return true;
    if (condition.contains(_random)) return null;
    if (!ConditionEvaluator.variablesOf(condition).every(known.containsKey)) return null;
    try {
      return const ConditionEvaluator().evaluate(condition, known);
    } on ConditionException {
      return null;
    }
  }

  /// The variable [effect] changes in the data map.
  static String _setsVariable(Effect effect) =>
      effect.op == EffectOp.metaSet ? "${StoryState.flagPrefix}${effect.variable}" : effect.variable;

  /// Applies [effects] to [known] where the result can be worked out from it. The variables of the others become
  /// unknown.
  static void _applyKnown(List<Effect> effects, Map<String, dynamic> known) {
    for (final effect in effects) {
      final variable = _setsVariable(effect);
      if (effect.op == EffectOp.metaSet) {
        known[variable] = true;
        continue;
      }
      final expr = effect.expr;
      final reads = {
        if (expr != null) ...ConditionEvaluator.variablesOf(expr),
        if (effect.op != EffectOp.set) effect.variable,
      };
      if ((expr != null && expr.contains(_random)) || !reads.every(known.containsKey)) {
        known.remove(variable);
        continue;
      }
      try {
        effect.apply(known);
      } on ConditionException {
        known.remove(variable);
      }
    }
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
