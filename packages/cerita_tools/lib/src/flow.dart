import 'model.dart';

/// A step from one flow node to another. [shown] is true when the item at the source node is shown on the way
/// (its time counts), false when it's skipped because its condition failed.
class FlowEdge {
  final int to;
  final bool shown;

  const FlowEdge(this.to, this.shown);
}

/// The story as a graph of items, following the engine's rules (engine §1): items run in order, conditional
/// items may be skipped, choices and branches jump to other conversations, and an ending stops the run.
///
/// Every conversation has one node per item plus an exit node after its last item. Reaching an exit node means
/// the engine runs out of items there. Conditions are never evaluated, so the graph holds every possible route.
/// A `CALL` isn't followed: it continues at the next item, and `stats` counts the called section as the CALL's
/// own time. A `RETURN` ends the path.
class FlowGraph {
  final List<ConversationNode> conversations;
  final Map<String, int> _indexByKey = {};
  final List<int> _base = [];
  final List<List<FlowEdge>> edges = [];
  final List<int> _conversationOf = [];

  FlowGraph(this.conversations) {
    for (var c = 0; c < conversations.length; c++) {
      _indexByKey.putIfAbsent(conversations[c].key, () => c);
      _base.add(edges.length);
      for (var i = 0; i <= conversations[c].items.length; i++) {
        edges.add([]);
        _conversationOf.add(c);
      }
    }
    for (var c = 0; c < conversations.length; c++) {
      final items = conversations[c].items;
      for (var i = 0; i < items.length; i++) {
        _link(_base[c] + i, items[i], _base[c] + i + 1);
      }
    }
  }

  int get length => edges.length;

  /// The first node of the conversation [key], or `null` if it doesn't exist.
  int? start(String key) {
    final index = _indexByKey[key];
    return index == null ? null : _base[index];
  }

  ConversationNode conversationOf(int node) => conversations[_conversationOf[node]];

  /// The item at [node], or `null` for an exit node.
  ItemNode? itemAt(int node) {
    final conversation = _conversationOf[node];
    final index = node - _base[conversation];
    final items = conversations[conversation].items;
    return index < items.length ? items[index] : null;
  }

  bool isExit(int node) => itemAt(node) == null;

  /// The node [target] points at from the conversation [from]: a conversation's first item, or a labelled item.
  int? resolve(TargetRef target, String from) {
    final index = _indexByKey[target.conversation(from)];
    if (index == null) return null;
    final label = target.label;
    if (label == null) return _base[index];
    final item = conversations[index].items.indexWhere((item) => item.label == label);
    return item < 0 ? null : _base[index] + item;
  }

  void _link(int node, ItemNode item, int next) {
    final out = edges[node];
    final from = conversationOf(node).key;
    if (item.condition != null) out.add(FlowEdge(next, false));
    void to(TargetRef? target) {
      final resolved = target == null ? next : resolve(target, from);
      if (resolved != null) out.add(FlowEdge(resolved, true));
    }

    switch (item) {
      case EndingItem() || ReturnItem():
        break;
      case JumpItem(isCall: false):
        to(item.target);
      case BranchItem():
        for (final route in item.routes) {
          to(route.target);
        }
        to(item.fallback);
      case ChoiceItem():
        // The engine skips a choice whose options are all hidden.
        if (item.options.every((option) => option.condition != null || option.once)) to(null);
        for (final option in item.options) {
          to(option.target);
        }
      default:
        to(null);
    }
  }
}

/// A run through the flow graph: the nodes in order and whether each one's item was shown.
class FlowPath {
  final List<int> nodes;
  final List<bool> shown;
  final double cost;

  const FlowPath(this.nodes, this.shown, this.cost);
}

typedef NodeCost = double Function(int node);

/// Cheapest and dearest runs from [from] to every node, where showing a node's item costs [cost] and skipping
/// it costs nothing.
class FlowRuns {
  final FlowGraph graph;
  final int from;
  final NodeCost cost;

  late final List<double> _shortest;
  late final List<(int, bool)?> _shortestVia;
  late final List<double> _longest;
  late final List<(int, bool)?> _longestVia;

  FlowRuns(this.graph, this.from, this.cost) {
    _computeShortest();
    _computeLongest();
  }

  /// The cheapest run that reaches [node], or `null` if no run does. The item at [node] isn't included.
  FlowPath? shortestTo(int node) => _path(node, _shortest, _shortestVia);

  /// The dearest run that reaches [node], counting each loop once.
  FlowPath? longestTo(int node) => _path(node, _longest, _longestVia);

  FlowPath? _path(int node, List<double> dist, List<(int, bool)?> via) {
    if (dist[node].isInfinite) return null;
    final nodes = <int>[node];
    final shown = <bool>[true];
    var current = node;
    while (current != from) {
      final (previous, wasShown) = via[current]!;
      nodes.add(previous);
      shown.add(wasShown);
      current = previous;
    }
    return FlowPath(nodes.reversed.toList(), shown.reversed.toList(), dist[node]);
  }

  void _computeShortest() {
    final n = graph.length;
    _shortest = List.filled(n, double.infinity);
    _shortestVia = List.filled(n, null);
    _shortest[from] = 0;
    final heap = _MinHeap()..push(0, from);
    while (heap.isNotEmpty) {
      final (dist, node) = heap.pop();
      if (dist > _shortest[node]) continue;
      for (final edge in graph.edges[node]) {
        final next = dist + (edge.shown ? cost(node) : 0);
        if (next < _shortest[edge.to]) {
          _shortest[edge.to] = next;
          _shortestVia[edge.to] = (node, edge.shown);
          heap.push(next, edge.to);
        }
      }
    }
  }

  /// Longest paths on the graph without its back edges, so each loop is counted once.
  void _computeLongest() {
    final n = graph.length;
    final state = List.filled(n, 0); // 0 new, 1 on the DFS stack, 2 done
    final order = <int>[];
    final back = <(int, int)>{};
    final stack = <(int, int)>[(from, 0)];
    state[from] = 1;
    while (stack.isNotEmpty) {
      final (node, index) = stack.last;
      final out = graph.edges[node];
      if (index < out.length) {
        stack[stack.length - 1] = (node, index + 1);
        final to = out[index].to;
        if (state[to] == 0) {
          state[to] = 1;
          stack.add((to, 0));
        } else if (state[to] == 1) {
          back.add((node, index));
        }
      } else {
        state[node] = 2;
        order.add(node);
        stack.removeLast();
      }
    }

    _longest = List.filled(n, double.infinity);
    _longestVia = List.filled(n, null);
    final dist = List.filled(n, double.negativeInfinity);
    dist[from] = 0;
    for (final node in order.reversed) {
      if (dist[node].isInfinite) continue;
      final out = graph.edges[node];
      for (var i = 0; i < out.length; i++) {
        if (back.contains((node, i))) continue;
        final edge = out[i];
        final next = dist[node] + (edge.shown ? cost(node) : 0);
        if (next > dist[edge.to]) {
          dist[edge.to] = next;
          _longestVia[edge.to] = (node, edge.shown);
        }
      }
    }
    for (var i = 0; i < n; i++) {
      if (!dist[i].isInfinite) _longest[i] = dist[i];
    }
  }
}

class _MinHeap {
  final List<(double, int)> _items = [];

  bool get isNotEmpty => _items.isNotEmpty;

  void push(double priority, int value) {
    _items.add((priority, value));
    var i = _items.length - 1;
    while (i > 0) {
      final parent = (i - 1) ~/ 2;
      if (_items[parent].$1 <= _items[i].$1) break;
      _swap(i, parent);
      i = parent;
    }
  }

  (double, int) pop() {
    final top = _items.first;
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      var i = 0;
      while (true) {
        final left = 2 * i + 1, right = left + 1;
        var smallest = i;
        if (left < _items.length && _items[left].$1 < _items[smallest].$1) smallest = left;
        if (right < _items.length && _items[right].$1 < _items[smallest].$1) smallest = right;
        if (smallest == i) break;
        _swap(i, smallest);
        i = smallest;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final tmp = _items[a];
    _items[a] = _items[b];
    _items[b] = tmp;
  }
}
