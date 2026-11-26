import 'dart:math';

import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../common/ending_view.dart';
import '../common/story_sheet.dart';
import '../l10n/story_language.dart';

/// The Chapters flowchart (CE-07): the [map]'s checkpoints and endings top to bottom, revealed as far as
/// [meta] has reached. Unreached nodes show "???". Tapping a reached checkpoint offers to continue from it
/// ([onSelect]) or replay its chapter ([onReplay], null hides it).
///
/// The chart only scrolls down. Nodes are at least [minNodeWidth] wide and as tall as the tallest reached
/// node's text, and a row with more nodes than fit across the screen wraps onto more lines, checkpoints first.
/// Lines into and out of a wrapped row run down the gaps between its columns, never under a node.
class RouteFlowchart extends StatelessWidget {
  /// The narrowest a node gets before a row wraps. Two fit across a 320 dp phone.
  static const minNodeWidth = 136.0;
  static const maxNodeWidth = 200.0;
  static const minNodeHeight = 56.0;
  static const rowGap = 44.0;

  /// The gap between the lines of a wrapped row.
  static const lineGap = 24.0;
  static const columnGap = 12.0;
  static const padding = 16.0;
  static const _nodePadding = EdgeInsets.symmetric(horizontal: 8, vertical: 6);

  final RouteMap map;
  final GlobalMetaState meta;
  final ValueChanged<Checkpoint> onSelect;
  final ValueChanged<Checkpoint>? onReplay;

  const RouteFlowchart({super.key, required this.map, required this.meta, required this.onSelect, this.onReplay});

  bool _reached(RouteNode node) => node.isEnding
      ? meta.unlockedEndingIds.contains(node.id)
      : meta.unlockedCheckpoints.containsKey(node.id);

  @override
  Widget build(BuildContext context) {
    if (map.rows.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final language = StoryLanguage.of(context);
    final checkpointTexts = <RouteNode, (String, String?, String?)>{};
    (String, String?, String?) checkpointTextOf(RouteNode node) =>
        checkpointTexts[node] ??= _checkpointText(language, node);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final available = width - 2 * padding;
        final widest = map.rows.fold(1, (widest, row) => max(widest, row.length));
        final fit = max(1, ((available + columnGap) / (minNodeWidth + columnGap)).floor());
        final columns = min(fit, widest);
        final nodeWidth = min(maxNodeWidth, (available - (columns - 1) * columnGap) / columns);
        final nodeHeight = _nodeHeight(context, nodeWidth - _nodePadding.horizontal, checkpointTextOf);

        // The gaps between the columns of a full line, or the left margin with one column.
        final lineLeft = (width - columns * nodeWidth - (columns - 1) * columnGap) / 2;
        final gutters = columns > 1
            ? [for (var column = 1; column < columns; column++) lineLeft + column * (nodeWidth + columnGap) - columnGap / 2]
            : [lineLeft - columnGap / 2];
        double gutterNear(double x) =>
            gutters.reduce((best, gutter) => (gutter - x).abs() < (best - x).abs() ? gutter : best);

        final boxes = <RouteNode, Rect>{};
        final rows = <RouteNode, (double, double)>{}; // The top and bottom of each node's row.
        var top = padding;
        for (final row in map.rows) {
          // A wrapped row keeps every line on the columns of the first, so the gaps between them stay clear.
          final wraps = row.length > columns;
          final ordered = wraps ? [...row.where((node) => !node.isEnding), ...row.where((node) => node.isEnding)] : row;
          final rowTop = top;
          for (var start = 0; start < ordered.length; start += columns) {
            final line = ordered.sublist(start, min(start + columns, ordered.length));
            final left = wraps ? lineLeft : (width - line.length * nodeWidth - (line.length - 1) * columnGap) / 2;
            for (final (column, node) in line.indexed) {
              boxes[node] = Rect.fromLTWH(left + column * (nodeWidth + columnGap), top, nodeWidth, nodeHeight);
            }
            top += nodeHeight + lineGap;
          }
          for (final node in row) {
            rows[node] = (rowTop, top - lineGap);
          }
          top += rowGap - lineGap;
        }
        final height = top - rowGap + padding;

        // From the current point down to [across], over to [x] and down to [y], with rounded corners.
        void jog(Path path, double from, double across, double x, double y) {
          final radius = min(lineGap / 2, (x - from).abs() / 2);
          if (radius < 1) {
            path.lineTo(x, y);
            return;
          }
          final sign = (x - from).sign;
          path
            ..lineTo(from, across - radius)
            ..quadraticBezierTo(from, across, from + sign * radius, across)
            ..lineTo(x - sign * radius, across)
            ..quadraticBezierTo(x, across, x, across + radius)
            ..lineTo(x, y);
        }

        // A curve from the bottom of one row to the top of the next. On a wrapped row, a line from a node above
        // its row's last line, or to a node below its first line, runs down the gutter nearest to that node.
        Path edge(RouteNode from, RouteNode to) {
          final (source, target) = (boxes[from]!, boxes[to]!);
          final (_, sourceBottom) = rows[from]!;
          final (targetTop, _) = rows[to]!;
          final path = Path()..moveTo(source.center.dx, source.bottom);
          var start = source.bottomCenter;
          if (source.bottom < sourceBottom) {
            start = Offset(gutterNear(source.center.dx), sourceBottom);
            jog(path, source.center.dx, source.bottom + lineGap / 2, start.dx, start.dy);
          }
          final end = target.top > targetTop ? gutterNear(target.center.dx) : target.center.dx;
          final middle = (start.dy + targetTop) / 2;
          path.cubicTo(start.dx, middle, end, middle, end, targetTop);
          if (target.top > targetTop) jog(path, end, target.top - lineGap / 2, target.center.dx, target.top);
          return path;
        }

        final lines = [
          for (final (from, to) in map.edges) (edge(from, to), _reached(from) && _reached(to)),
        ]..sort((a, b) => (a.$2 ? 1 : 0) - (b.$2 ? 1 : 0));

        return SingleChildScrollView(
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _EdgePainter(lines, taken: scheme.primary, open: scheme.outlineVariant),
                    ),
                  ),
                ),
                for (final MapEntry(key: node, value: box) in boxes.entries)
                  Positioned.fromRect(rect: box, child: _node(context, node, checkpointTextOf)),
              ],
            ),
          ),
        );
      },
    );
  }

  /// One height for every node: the tallest reached node's text laid out at [contentWidth], in the player's
  /// language and text size.
  double _nodeHeight(
    BuildContext context,
    double contentWidth,
    (String, String?, String?) Function(RouteNode) checkpointTextOf,
  ) {
    final styles = _Styles.of(context);
    final language = StoryLanguage.of(context);
    final base = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double measure(String? text, TextStyle? style, {int? maxLines, bool wraps = true}) {
      if (text == null) return 0;
      final painter = TextPainter(
        text: TextSpan(text: text, style: base.merge(style)),
        textDirection: direction,
        textScaler: scaler,
        maxLines: maxLines,
        ellipsis: maxLines == null ? null : "…",
      )..layout(maxWidth: wraps ? contentWidth : double.infinity);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    var content = max(24.0, measure("???", styles.unknown));
    for (final node in map.nodes.where(_reached)) {
      if (node.ending case final ending?) {
        final localized = ending.localized(language.localizer);
        final badge = measure(language.strings.endingBadge(localized.category), EndingBadge.textStyle, wraps: false);
        content = max(content, badge + EndingBadge.padding.vertical + 4 + measure(localized.title, styles.small, maxLines: 2));
      } else {
        final (chapter, title, found) = checkpointTextOf(node);
        content = max(
          content,
          measure(chapter, styles.chapter, maxLines: 1) +
              measure(title, styles.title, maxLines: 2) +
              measure(found, styles.found),
        );
      }
    }
    return max(minNodeHeight, (content + _nodePadding.vertical).ceilToDouble());
  }

  /// A reached checkpoint's chapter (or day), title, and how many of the endings after it were found.
  (String, String?, String?) _checkpointText(StoryLanguage language, RouteNode node) {
    final conversation = node.conversation.localized(language.localizer);
    final day = conversation.scene.day;
    final chapter = conversation.chapter ?? (day == null ? conversation.key : language.strings.day(day));
    final endings = map.endingsAfter(node);
    final found = endings.where(meta.unlockedEndingIds.contains).length;
    return (chapter, conversation.title, endings.isEmpty ? null : language.strings.endingsFound(found, endings.length));
  }

  Widget _node(
    BuildContext context,
    RouteNode node,
    (String, String?, String?) Function(RouteNode) checkpointTextOf,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = StoryLanguage.of(context);
    final strings = language.strings;
    final styles = _Styles.of(context);

    Widget card({required Widget child, Color? color, VoidCallback? onTap, String? label}) => Semantics(
          label: label,
          button: onTap != null,
          child: Card(
            margin: EdgeInsets.zero,
            color: color,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(padding: _nodePadding, child: Center(child: child)),
            ),
          ),
        );

    final locked = scheme.surfaceContainerHighest.withAlpha(140);
    if (!_reached(node)) {
      return node.isEnding
          ? card(color: locked, label: strings.lockedEnding, child: Icon(Icons.lock_outline, color: scheme.outline))
          : card(
              color: locked,
              label: strings.notReachedYet,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 16, color: scheme.outline),
                  const SizedBox(width: 6),
                  Text("???", style: styles.unknown),
                ],
              ),
            );
    }

    if (node.ending case final ending?) {
      final localized = ending.localized(language.localizer);
      return card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(fit: BoxFit.scaleDown, child: EndingBadge(category: localized.category)),
            const SizedBox(height: 4),
            Text(
              localized.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: styles.small,
            ),
          ],
        ),
      );
    }

    final (chapter, title, found) = checkpointTextOf(node);
    return card(
      color: scheme.primaryContainer,
      onTap: () => _offer(context, meta.unlockedCheckpoints[node.id]!, chapter, title),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(chapter, maxLines: 1, overflow: TextOverflow.ellipsis, style: styles.chapter),
          if (title != null)
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: styles.title),
          if (found != null) Text(found, textAlign: TextAlign.center, style: styles.found),
        ],
      ),
    );
  }

  void _offer(BuildContext context, Checkpoint checkpoint, String chapter, String? title) {
    final strings = StoryLanguage.of(context).strings;
    StorySheet.show<void>(
      context,
      title: chapter,
      icon: Icons.flag_outlined,
      builder: (sheetContext) {
        void close(VoidCallback action) {
          Navigator.of(sheetContext).pop();
          action();
        }

        final onReplay = this.onReplay;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null) ListTile(title: Text(title)),
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: Text(strings.playFromHere),
                onTap: () => close(() => onSelect(checkpoint)),
              ),
              if (onReplay != null)
                ListTile(
                  leading: const Icon(Icons.replay),
                  title: Text(strings.replayChapter),
                  onTap: () => close(() => onReplay(checkpoint)),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The node text styles, shared by the nodes and the height they're measured at.
class _Styles {
  final TextStyle? chapter;
  final TextStyle? title;
  final TextStyle? found;
  final TextStyle? small;
  final TextStyle? unknown;

  const _Styles({this.chapter, this.title, this.found, this.small, this.unknown});

  factory _Styles.of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    return _Styles(
      chapter: text.titleSmall?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold),
      title: text.bodySmall?.copyWith(color: scheme.onPrimaryContainer),
      found: text.labelSmall?.copyWith(color: scheme.onPrimaryContainer.withAlpha(180)),
      small: text.bodySmall,
      unknown: text.titleMedium?.copyWith(color: scheme.outline),
    );
  }
}

/// The lines from each node down to the nodes it leads to. [taken] colours a line between two reached nodes.
class _EdgePainter extends CustomPainter {
  final List<(Path, bool)> lines;
  final Color taken;
  final Color open;

  const _EdgePainter(this.lines, {required this.taken, required this.open});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final (path, reached) in lines) {
      canvas.drawPath(path, paint..color = reached ? taken : open);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter oldDelegate) =>
      oldDelegate.lines != lines || oldDelegate.taken != taken || oldDelegate.open != open;
}
