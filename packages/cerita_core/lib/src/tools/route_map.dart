import 'dart:math';

import '../data/conversation.dart';
import '../data/items/ending.dart';
import 'story_graph.dart';

/// A checkpoint or an ending on a [RouteMap].
class RouteNode {
  /// The checkpoint, or the first conversation with the ending.
  final Conversation conversation;

  /// The `ENDING` item of an ending node. Null for a checkpoint.
  final EndingItemType? ending;

  /// The row the node is drawn in, from 0 at the top.
  final int layer;

  const RouteNode._(this.conversation, this.ending, this.layer);

  bool get isEnding => ending != null;

  /// The checkpoint's conversation key, or the `ending_id`.
  String get id => ending?.endingId ?? conversation.key;

  @override
  String toString() => isEnding ? "ending $id" : id;
}

/// The chapter-level map of a story: checkpoints and endings, and which lead to which. Every other conversation
/// is folded into the checkpoint before it. Built from a [StoryGraph] for the Chapters flowchart. See the
/// authoring tools spec §2.1.
class RouteMap {
  /// The nodes row by row, each row in drawing order.
  final List<List<RouteNode>> rows;

  /// Every node a node leads to, loops included.
  final Map<RouteNode, List<RouteNode>> _next;

  /// The edges to draw: the ones that go down the map, not back up a loop.
  final List<(RouteNode, RouteNode)> edges;

  const RouteMap._(this.rows, this._next, this.edges);

  factory RouteMap(StoryGraph graph) {
    final byKey = {for (final conversation in graph.conversations) conversation.key: conversation};
    bool isCheckpoint(String key) => byKey[key]?.checkpoint ?? false;
    final endings = <String, (Conversation, EndingItemType)>{};

    // Pre-index links per conversation by itemIndex (null = scene-level links like call hangup).
    final linksByConv = <String, Map<int?, List<StoryLink>>>{};
    for (final conversation in graph.conversations) {
      final grouped = <int?, List<StoryLink>>{};
      for (final link in StoryLink.of(conversation)) {
        grouped.putIfAbsent(link.itemIndex, () => []).add(link);
      }
      linksByConv[conversation.key] = grouped;
    }

    // Node ids: `c:<conversation key>` for checkpoints, `e:<ending_id>` for endings.
    List<String> successors(String start) {
      final found = <String>{};

      // Depth first in item order, so routes come out in the order their options are written.
      final seen = {start};
      void walk(String key) {
        final conversation = byKey[key];
        if (conversation == null) return;
        final grouped = linksByConv[key] ?? const {};

        void follow(StoryLink link) {
          final target = link.targetKey;
          if (isCheckpoint(target)) {
            if (target != start) found.add("c:$target");
          } else if (seen.add(target)) {
            walk(target);
          }
        }

        for (final link in grouped[null] ?? const <StoryLink>[]) {
          follow(link);
        }
        for (final (index, item) in conversation.conversations.indexed) {
          if (item is EndingItemType) {
            endings.putIfAbsent(item.endingId, () => (conversation, item));
            found.add("e:${item.endingId}");
          }
          for (final link in grouped[index] ?? const <StoryLink>[]) {
            follow(link);
          }
        }
      }

      walk(start);
      return found.toList();
    }

    final roots =
        isCheckpoint(Conversation.indexKey) ? ["c:${Conversation.indexKey}"] : successors(Conversation.indexKey);
    final next = <String, List<String>>{};
    final order = <String>[];
    final queue = [...roots];
    for (var head = 0; head < queue.length; head++) {
      final id = queue[head];
      if (next.containsKey(id)) continue;
      order.add(id);
      next[id] = id.startsWith("c:") ? successors(id.substring(2)) : const [];
      queue.addAll(next[id]!);
    }

    if (order.isEmpty) return const RouteMap._([], {}, []);

    // Edges back to a node still being visited close a loop. The rest form a DAG, laid out by longest path.
    final state = <String, bool>{};
    final back = <(String, String)>{};
    final finished = <String>[];
    void visit(String id) {
      state[id] = false;
      for (final target in next[id]!) {
        if (state[target] == false) {
          back.add((id, target));
        } else if (state[target] == null) {
          visit(target);
        }
      }
      state[id] = true;
      finished.add(id);
    }

    roots.where((root) => state[root] == null).forEach(visit);
    final layer = {for (final id in order) id: 0};
    for (final id in finished.reversed) {
      for (final target in next[id]!) {
        if (!back.contains((id, target))) layer[target] = max(layer[target]!, layer[id]! + 1);
      }
    }

    // Rows in story order, then each row below sorted by where the nodes leading to it sit.
    final parents = <String, List<String>>{};
    final orderIndex = <String, int>{};
    for (final (i, id) in order.indexed) {
      orderIndex[id] = i;
      for (final target in next[id]!) {
        if (!back.contains((id, target))) parents.putIfAbsent(target, () => []).add(id);
      }
    }
    final rowCount = layer.values.fold(0, max) + 1;
    final rowIds = List.generate(rowCount, (_) => <String>[]);
    for (final id in order) {
      rowIds[layer[id]!].add(id);
    }
    final position = <String, int>{};
    for (final row in rowIds) {
      double place(String id) {
        final above = parents[id] ?? const [];
        return above.isEmpty ? -1 : above.map((parent) => position[parent] ?? 0).reduce((a, b) => a + b) / above.length;
      }

      final placed = {for (final id in row) id: place(id)};
      row.sort((a, b) {
        final byPlace = placed[a]!.compareTo(placed[b]!);
        return byPlace != 0 ? byPlace : orderIndex[a]!.compareTo(orderIndex[b]!);
      });
      for (final (index, id) in row.indexed) {
        position[id] = index;
      }
    }

    final nodes = <String, RouteNode>{
      for (final id in order)
        id: switch (id.substring(0, 2)) {
          "c:" => RouteNode._(byKey[id.substring(2)]!, null, layer[id]!),
          _ => RouteNode._(endings[id.substring(2)]!.$1, endings[id.substring(2)]!.$2, layer[id]!),
        },
    };
    return RouteMap._(
      [for (final row in rowIds) [for (final id in row) nodes[id]!]],
      {for (final id in order) nodes[id]!: [for (final target in next[id]!) nodes[target]!]},
      [
        for (final id in order)
          for (final target in next[id]!)
            if (!back.contains((id, target))) (nodes[id]!, nodes[target]!),
      ],
    );
  }

  Iterable<RouteNode> get nodes => rows.expand((row) => row);

  /// The nodes [node] leads to, loops included.
  List<RouteNode> next(RouteNode node) => _next[node] ?? const [];

  /// Whether the story branches: some node leads to two or more nodes.
  bool get branches => _next.values.any((targets) => targets.length > 1);

  /// The `ending_id`s reachable from [node].
  Set<String> endingsAfter(RouteNode node) {
    final seen = <RouteNode>{};
    final queue = [...next(node)];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (seen.add(current)) queue.addAll(next(current));
    }
    return {for (final reached in seen) ?reached.ending?.endingId};
  }
}
