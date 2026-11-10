import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../common/tagged_text.dart';
import '../story_controller.dart';

/// The NVL text box: the lines of the current page on a dimmed full-screen panel, newest at the bottom.
/// Only the newest line types out, through [typewriterKey].
class NvlPage extends StatelessWidget {
  final StoryController controller;
  final GlobalKey<TypewriterTextState> typewriterKey;
  final bool instant;
  final int msPerChar;
  final Duration? autoResume;
  final VoidCallback? onTyped;

  const NvlPage({
    super.key,
    required this.controller,
    required this.typewriterKey,
    this.instant = false,
    this.msPerChar = 40,
    this.autoResume,
    this.onTyped,
  });

  /// The page's lines: VN transcript entries from the page start that show text.
  static List<TranscriptEntry> linesOf(StoryController controller) => [
        for (final entry in controller.history.skip(controller.stage.pageStart))
          if (entry.mode == SceneMode.vn &&
              (entry.isPlayer ||
                  switch (entry.itemType) {
                    TextItemType() || NarrationItemType() || ChoiceItemType() || InputItemType() => true,
                    _ => false,
                  }))
            entry,
      ];

  @override
  Widget build(BuildContext context) {
    final lines = linesOf(controller);
    final scheme = Theme.of(context).colorScheme;
    final accent = Color.lerp(scheme.primary, Colors.white, 0.45)!;
    const textStyle = TextStyle(color: Colors.white, fontSize: 17, height: 1.5);

    Widget line(TranscriptEntry entry, {required bool newest}) {
      if (entry.isPlayer) {
        return Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text("› ${entry.playerText}", style: textStyle.copyWith(color: accent)),
        );
      }
      final item = entry.itemType!;
      final speaker = item is NarrationItemType ? null : controller.profileOf(item)?.name;
      final style = TextStyle(fontStyle: item is NarrationItemType ? FontStyle.italic : null);
      final text = item.getText() ?? "";

      Widget withSpeaker(Widget body) => speaker == null
          ? body
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(speaker, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14)),
                body,
              ],
            );

      if (!newest) return withSpeaker(TaggedText(text, style: style));
      return TypewriterText(
        text,
        key: typewriterKey,
        style: style,
        instant: instant,
        msPerChar: msPerChar,
        autoResume: autoResume,
        onTyped: onTyped,
        builder: (context, body, done) => withSpeaker(Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(child: body),
            AnimatedOpacity(
              opacity: done ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.arrow_drop_down, color: accent),
            ),
          ],
        )),
      );
    }

    final newestIndex = lines.lastIndexWhere((entry) => !entry.isPlayer);
    return ColoredBox(
      color: Colors.black.withAlpha(185),
      child: SafeArea(
        child: DefaultTextStyle.merge(
          style: textStyle,
          child: ListView.separated(
            reverse: true,
            padding: const EdgeInsets.fromLTRB(28, 110, 28, 32),
            itemCount: lines.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final at = lines.length - 1 - index;
              return line(lines[at], newest: at == newestIndex);
            },
          ),
        ),
      ),
    );
  }
}
