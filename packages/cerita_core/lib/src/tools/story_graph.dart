import '../data/conversation.dart';
import '../data/items/branch.dart';
import '../data/items/choice.dart';
import '../data/items/ending.dart';
import '../data/items/evidence.dart';
import '../data/items/flow.dart';

enum LinkKind { choice, branch, fallback, jump, call, hangUp }

/// A `target` of an item or scene: where a choice, branch, jump or call goes, or where a call goes once hung up.
class StoryLink {
  final String from;

  /// The item the target is in. Null for the scene's own target, a call's `hangup`.
  final int? itemIndex;
  final String target;
  final LinkKind kind;

  /// Choice text or branch condition.
  final String? label;

  /// Where in the item the target is, as JSON keys and indexes: `["choices", 1, "target"]`, `["branches", 0]`,
  /// `["fallback_target"]`, `["responses", 0, "target"]` or `["scene", "hangup"]`. Empty for a `JUMP` or `CALL`.
  final List<Object> path;

  const StoryLink({
    required this.from,
    required this.itemIndex,
    required this.target,
    required this.kind,
    this.label,
    this.path = const [],
  });

  /// The conversation [target] points at: [from] for a `#label` in the same conversation.
  String get targetKey {
    final hash = target.indexOf("#");
    final key = hash < 0 ? target : target.substring(0, hash);
    return key.isEmpty ? from : key;
  }

  /// The label part of [target], if any.
  String? get targetLabel {
    final hash = target.indexOf("#");
    return hash < 0 ? null : target.substring(hash + 1);
  }

  /// Every target in [conversation]: the scene's, then the items' in order.
  static Iterable<StoryLink> of(Conversation conversation) sync* {
    if (conversation.hasScene) {
      if (conversation.scene.hangUp case final target?) {
        yield StoryLink(
          from: conversation.key,
          itemIndex: null,
          target: target,
          kind: LinkKind.hangUp,
          path: const ["scene", "hangup"],
        );
      }
    }
    for (final (index, item) in conversation.conversations.indexed) {
      StoryLink link(String target, LinkKind kind, [String? label, List<Object> path = const []]) =>
          StoryLink(from: conversation.key, itemIndex: index, target: target, kind: kind, label: label, path: path);
      switch (item) {
        case EvidenceItemType(:final responses, :final retry, :final fallback, :final timeout):
          for (final (at, response) in responses.indexed) {
            if (response.target case final target?) {
              yield link(target, LinkKind.choice, "Present ${response.clue}", ["responses", at, "target"]);
            }
          }
          if (retry?.target case final target?) yield link(target, LinkKind.choice, "retry", ["retry", "target"]);
          if (fallback?.target case final target?) yield link(target, LinkKind.fallback, null, ["fallback", "target"]);
          if (timeout?.target case final target?) yield link(target, LinkKind.choice, "time out", ["timeout", "target"]);
        case ChoiceItemType(:final choices):
          for (final (option, choice) in choices.indexed) {
            final target = choice.target;
            if (target != null) yield link(target, LinkKind.choice, choice.text, ["choices", option, "target"]);
          }
        case BranchItemType(:final branches, :final fallbackTarget):
          for (final (route, branch) in branches.indexed) {
            yield link(branch.target, LinkKind.branch, branch.condition, ["branches", route]);
          }
          if (fallbackTarget != null) yield link(fallbackTarget, LinkKind.fallback, null, ["fallback_target"]);
        case JumpItemType(:final target):
          yield link(target, LinkKind.jump);
        case CallItemType(:final target):
          yield link(target, LinkKind.call);
      }
    }
  }
}

/// The conversations of a story and the targets between them.
class StoryGraph {
  final List<Conversation> conversations;

  const StoryGraph(this.conversations);

  /// Links between different conversations.
  List<StoryLink> get links => [
        for (final conversation in conversations)
          ...StoryLink.of(conversation).where((link) => link.targetKey != conversation.key),
      ];

  /// Keys of the conversations reachable from [Conversation.indexKey].
  Set<String> get reachable {
    final byKey = {for (final conversation in conversations) conversation.key: conversation};
    final seen = <String>{};
    final queue = [Conversation.indexKey];
    while (queue.isNotEmpty) {
      final key = queue.removeLast();
      final conversation = byKey[key];
      if (conversation == null || !seen.add(key)) continue;
      queue.addAll(StoryLink.of(conversation).map((link) => link.targetKey));
    }
    return seen;
  }

  static final _mermaidUnsafe = RegExp(r"[^A-Za-z0-9_]");

  /// A Mermaid flowchart: conversations as nodes (endings rounded), targets as edges. `CALL`s are dashed.
  String toMermaid() {
    String id(String key) => key.replaceAll(_mermaidUnsafe, "_");
    String quote(String text) => '"${text.replaceAll('"', "#quot;")}"';

    final lines = ["flowchart TD"];
    for (final conversation in conversations) {
      final name = [conversation.chapter, conversation.title].whereType<String>().join(" · ");
      final label = quote(name.isEmpty ? conversation.key : "$name<br/>${conversation.key}");
      final ending = conversation.conversations.any((item) => item is EndingItemType);
      lines.add("    ${id(conversation.key)}${ending ? "([$label])" : "[$label]"}");
    }
    final drawn = <String>{};
    for (final link in links) {
      final arrow = link.kind == LinkKind.call ? "-.->" : "-->";
      final text = switch (link.kind) {
        LinkKind.choice || LinkKind.branch => link.label,
        LinkKind.fallback => "otherwise",
        LinkKind.call => "CALL",
        LinkKind.hangUp => "hang up",
        LinkKind.jump => null,
      };
      final line = "    ${id(link.from)} $arrow${text == null ? "" : "|${quote(_short(text))}|"} ${id(link.targetKey)}";
      if (drawn.add(line)) lines.add(line);
    }
    return "${lines.join("\n")}\n";
  }

  static String _short(String text) => text.length <= 40 ? text : "${text.substring(0, 39)}…";
}
