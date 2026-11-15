import 'flow.dart';
import 'model.dart';
import 'project.dart';

/// Words and time of one stretch of story.
class Measure {
  final int words;
  final double seconds;

  const Measure(this.words, this.seconds);

  double get minutes => seconds / 60;

  Map<String, Object?> toJson() => {"words": words, "minutes": _round(minutes)};
}

class ConversationStats {
  final String key;
  final String? chapter;

  /// Every item shown.
  final Measure total;

  const ConversationStats(this.key, this.chapter, this.total);
}

class ChapterStats {
  final String name;
  final Measure total;

  const ChapterStats(this.name, this.total);
}

class RunStats {
  final Measure measure;

  /// Conversation keys in the order the run visits them.
  final List<String> path;

  const RunStats(this.measure, this.path);

  Map<String, Object?> toJson() => {...measure.toJson(), "path": path};
}

class EndingStats {
  final String id;
  final String category;
  final RunStats shortest;
  final RunStats longest;

  const EndingStats(this.id, this.category, this.shortest, this.longest);
}

/// The playtime report (spec §3.2).
class StoryStats {
  final String locale;
  final num wpm;
  final List<ConversationStats> conversations;
  final List<ChapterStats> chapters;
  final List<EndingStats> endings;
  final RunStats? criticalPath;

  const StoryStats({
    required this.locale,
    required this.wpm,
    required this.conversations,
    required this.chapters,
    required this.endings,
    required this.criticalPath,
  });

  Map<String, Object?> toJson() => {
        "locale": locale,
        "wpm": wpm,
        "conversations": [
          for (final c in conversations) {"key": c.key, "chapter": c.chapter, ...c.total.toJson()},
        ],
        "chapters": [
          for (final c in chapters) {"name": c.name, ...c.total.toJson()},
        ],
        "endings": [
          for (final e in endings)
            {"id": e.id, "category": e.category, "shortest": e.shortest.toJson(), "longest": e.longest.toJson()},
        ],
        "critical_path": criticalPath?.toJson(),
      };

  String format() {
    final out = StringBuffer("Locale $locale, $wpm wpm\n");
    String row(String name, Measure m) =>
        "${name.padRight(28)} ${m.words.toString().padLeft(7)} ${m.minutes.toStringAsFixed(1).padLeft(7)}\n";

    out.write("\n${"Chapters".padRight(28)} ${"words".padLeft(7)} ${"min".padLeft(7)}\n");
    for (final chapter in chapters) {
      out.write(row(chapter.name, chapter.total));
    }
    out.write("\n${"Conversations".padRight(28)} ${"words".padLeft(7)} ${"min".padLeft(7)}\n");
    for (final conversation in conversations) {
      out.write(row(conversation.key, conversation.total));
    }
    out.write("\n${"Endings".padRight(28)} ${"shortest".padLeft(9)} ${"longest".padLeft(9)}  longest run\n");
    for (final ending in endings) {
      out.write("${"${ending.id} (${ending.category})".padRight(28)} "
          "${"${ending.shortest.measure.minutes.toStringAsFixed(1)} min".padLeft(9)} "
          "${"${ending.longest.measure.minutes.toStringAsFixed(1)} min".padLeft(9)}  "
          "${ending.longest.path.join(" > ")}\n");
    }
    final critical = criticalPath;
    if (critical != null) {
      out.write("\nCritical path: ${critical.measure.minutes.toStringAsFixed(1)} min, "
          "${critical.measure.words} words, ${critical.path.join(" > ")}\n");
    }
    return out.toString();
  }
}

double _round(double value) => (value * 10).round() / 10;

/// Words in [text]. `{{VAR}}` counts as one word.
int countWords(String text) =>
    text.replaceAll(RegExp(r"{{[a-zA-Z0-9_]+}}"), "X").split(RegExp(r"\s+")).where((word) {
      return word.contains(RegExp(r"[\p{L}\p{N}]", unicode: true));
    }).length;

/// Builds the playtime report in [locale] (default: the source locale) at [wpm] words per minute (default:
/// the story's setting for that locale).
StoryStats storyStats(StoryProject project, {String? locale, num? wpm}) {
  final config = project.config;
  final activeLocale = locale ?? config.sourceLocale;
  final speed = wpm ?? config.stats.wpmFor(activeLocale);
  final pacing = config.stats;

  int words(Localized? text) {
    final value = text?.textFor(activeLocale, config.sourceLocale);
    return value == null ? 0 : countWords(value);
  }

  Measure measure(ItemNode item) {
    var count = 0;
    var extra = 0.0;
    for (final entry in item.texts.entries) {
      if (entry.key != "tts") count += words(entry.value);
    }
    switch (item) {
      case LineItem():
        extra = (item.typingMs ?? 0) / 1000;
      case MediaItem():
        extra = pacing.mediaSeconds + (item.typingMs ?? 0) / 1000;
      case ChoiceItem():
        for (final option in item.options) {
          count += words(option.texts["text"]);
        }
        extra = pacing.choiceSeconds.toDouble();
      case InputItem():
        extra = pacing.inputSeconds.toDouble();
      case WaitItem():
        extra = item.durationMs / 1000;
      default:
        break;
    }
    return Measure(count, count / speed * 60 + extra);
  }

  final conversations = project.conversationsByKey.values.toList();
  final graph = FlowGraph(conversations);
  final measures = List<Measure?>.generate(graph.length, (node) {
    final item = graph.itemAt(node);
    return item == null ? null : measure(item);
  });
  double cost(int node) => measures[node]?.seconds ?? 0;

  // Conversations in the order a reader meets them: breadth first from index, then the unreachable ones by key.
  final ordered = <ConversationNode>[];
  final start = graph.start(ConversationNode.indexKey);
  if (start != null) {
    final seen = <String>{};
    final queue = [graph.conversationOf(start)];
    seen.add(queue.first.key);
    while (queue.isNotEmpty) {
      final conversation = queue.removeAt(0);
      ordered.add(conversation);
      for (final key in _targets(conversation)) {
        final next = project.conversationsByKey[key];
        if (next != null && seen.add(key)) queue.add(next);
      }
    }
  }
  ordered.addAll(conversations.where((c) => !ordered.contains(c)).toList()..sort((a, b) => a.key.compareTo(b.key)));

  final conversationStats = [
    for (final conversation in ordered)
      ConversationStats(
        conversation.key,
        conversation.chapter?.textFor(activeLocale, config.sourceLocale),
        conversation.items.map(measure).fold(const Measure(0, 0), (a, b) => Measure(a.words + b.words, a.seconds + b.seconds)),
      ),
  ];
  final chapterTotals = <String, Measure>{};
  for (final c in conversationStats) {
    final name = c.chapter ?? "(no chapter)";
    final total = chapterTotals[name] ?? const Measure(0, 0);
    chapterTotals[name] = Measure(total.words + c.total.words, total.seconds + c.total.seconds);
  }

  final endings = <EndingStats>[];
  RunStats? critical;
  if (start != null) {
    final runs = FlowRuns(graph, start, cost);
    RunStats run(FlowPath path, int endingNode) {
      var count = 0;
      final keys = <String>[];
      for (var i = 0; i < path.nodes.length; i++) {
        final node = path.nodes[i];
        if (path.shown[i]) count += measures[node]?.words ?? 0;
        final key = graph.conversationOf(node).key;
        if (keys.isEmpty || keys.last != key) keys.add(key);
      }
      return RunStats(Measure(count, path.cost + cost(endingNode)), keys);
    }

    final byId = <String, EndingStats>{};
    for (var node = 0; node < graph.length; node++) {
      final item = graph.itemAt(node);
      if (item is! EndingItem) continue;
      final shortest = runs.shortestTo(node);
      final longest = runs.longestTo(node);
      if (shortest == null || longest == null) continue;
      final stats = EndingStats(item.endingId, item.category, run(shortest, node), run(longest, node));
      final previous = byId[item.endingId];
      byId[item.endingId] = previous == null
          ? stats
          : EndingStats(
              item.endingId,
              item.category,
              previous.shortest.measure.seconds <= stats.shortest.measure.seconds ? previous.shortest : stats.shortest,
              previous.longest.measure.seconds >= stats.longest.measure.seconds ? previous.longest : stats.longest,
            );
    }
    endings.addAll(byId.values);
    for (final ending in endings) {
      if (critical == null || ending.longest.measure.seconds > critical.measure.seconds) critical = ending.longest;
    }
  }

  return StoryStats(
    locale: activeLocale,
    wpm: speed,
    conversations: conversationStats,
    chapters: [for (final entry in chapterTotals.entries) ChapterStats(entry.key, entry.value)],
    endings: endings,
    criticalPath: critical,
  );
}

Iterable<String> _targets(ConversationNode conversation) sync* {
  for (final item in conversation.items) {
    switch (item) {
      case ChoiceItem():
        for (final option in item.options) {
          if (option.target != null) yield option.target!.key;
        }
      case BranchItem():
        for (final route in item.routes) {
          yield route.target.key;
        }
        if (item.fallback != null) yield item.fallback!.key;
      default:
        break;
    }
  }
}

