import 'dart:math';

import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../common/ending_view.dart';
import '../l10n/story_language.dart';

/// The Chapters flowchart (CE-07): the [map]'s checkpoints and endings top to bottom, revealed as far as
/// [meta] has reached. Unreached nodes show "???". Tapping a reached checkpoint offers to continue from it
/// ([onSelect]) or replay its chapter ([onReplay], null hides it).
class RouteFlowchart extends StatelessWidget {
  static const nodeHeight = 84.0;
  static const rowGap = 44.0;
  static const columnGap = 12.0;
  static const padding = 16.0;

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
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final widest = map.rows.fold(1, (widest, row) => max(widest, row.length));
        final nodeWidth =
            ((constraints.maxWidth - 2 * padding - (widest - 1) * columnGap) / widest).clamp(84.0, 168.0);
        final width = max(constraints.maxWidth, 2 * padding + widest * nodeWidth + (widest - 1) * columnGap);
        final height = 2 * padding + map.rows.length * (nodeHeight + rowGap) - rowGap;

        final boxes = <RouteNode, Rect>{};
        for (final (index, row) in map.rows.indexed) {
          final rowWidth = row.length * nodeWidth + (row.length - 1) * columnGap;
          for (final (column, node) in row.indexed) {
            final left = (width - rowWidth) / 2 + column * (nodeWidth + columnGap);
            boxes[node] = Rect.fromLTWH(left, padding + index * (nodeHeight + rowGap), nodeWidth, nodeHeight);
          }
        }
        final lines = [
          for (final (from, to) in map.edges)
            (boxes[from]!.bottomCenter, boxes[to]!.topCenter, _reached(from) && _reached(to)),
        ];

        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _EdgePainter(lines, taken: scheme.primary, open: scheme.outlineVariant),
                    ),
                  ),
                  for (final MapEntry(key: node, value: box) in boxes.entries)
                    Positioned.fromRect(rect: box, child: _node(context, node)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _node(BuildContext context, RouteNode node) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = StoryLanguage.of(context);
    final strings = language.strings;
    final small = theme.textTheme.bodySmall;

    Widget card({required Widget child, Color? color, VoidCallback? onTap, String? label}) => Semantics(
          label: label,
          button: onTap != null,
          child: Card(
            margin: EdgeInsets.zero,
            color: color,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Center(child: child),
              ),
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
                  Text("???", style: theme.textTheme.titleMedium?.copyWith(color: scheme.outline)),
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
              style: small,
            ),
          ],
        ),
      );
    }

    final conversation = node.conversation.localized(language.localizer);
    final day = conversation.scene.day;
    final chapter = conversation.chapter ?? (day == null ? conversation.key : strings.day(day));
    final endings = map.endingsAfter(node);
    final found = endings.where(meta.unlockedEndingIds.contains).length;
    return card(
      color: scheme.primaryContainer,
      onTap: () => _offer(context, meta.unlockedCheckpoints[node.id]!, chapter, conversation.title),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            chapter,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold),
          ),
          if (conversation.title case final title?)
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: small?.copyWith(color: scheme.onPrimaryContainer),
            ),
          if (endings.isNotEmpty)
            Text(
              strings.endingsFound(found, endings.length),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onPrimaryContainer.withAlpha(180)),
            ),
        ],
      ),
    );
  }

  void _offer(BuildContext context, Checkpoint checkpoint, String chapter, String? title) {
    final strings = StoryLanguage.of(context).strings;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        void close(VoidCallback action) {
          Navigator.of(sheetContext).pop();
          action();
        }

        final onReplay = this.onReplay;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(chapter, style: Theme.of(sheetContext).textTheme.titleMedium),
                subtitle: title == null ? null : Text(title),
              ),
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

/// Lines from each node down to the nodes it leads to. [taken] colours a line between two reached nodes.
class _EdgePainter extends CustomPainter {
  final List<(Offset, Offset, bool)> lines;
  final Color taken;
  final Color open;

  const _EdgePainter(this.lines, {required this.taken, required this.open});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final (from, to, reached) in lines) {
      final middle = (from.dy + to.dy) / 2;
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(from.dx, middle, to.dx, middle, to.dx, to.dy);
      canvas.drawPath(path, paint..color = reached ? taken : open);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter oldDelegate) =>
      oldDelegate.lines != lines || oldDelegate.taken != taken || oldDelegate.open != open;
}
