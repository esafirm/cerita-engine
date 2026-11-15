import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../common/tagged_text.dart';

/// Visual hooks of the story views. Subclass it to restyle the story (see the `cerita_ui` package)
/// and provide it with [StorySkinScope]. The defaults are the plain Material look.
class StorySkin {
  const StorySkin();

  static StorySkin of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StorySkinScope>()?.skin ?? const StorySkin();

  /// Duration of the switch between presentation modes, and between VN conversations.
  Duration get sceneTransitionDuration => const Duration(milliseconds: 500);

  /// Builds the switch to a scene shown in [mode]. The outgoing scene gets the same transition
  /// with [animation] running in reverse.
  Widget sceneTransition(SceneMode mode, Animation<double> animation, Widget child) =>
      FadeTransition(opacity: animation, child: child);

  Duration get backgroundTransitionDuration => const Duration(milliseconds: 700);

  Widget backgroundTransition(Animation<double> animation, Widget child) =>
      FadeTransition(opacity: animation, child: child);

  /// Duration of a character sprite entering, leaving or changing expression.
  Duration get spriteTransitionDuration => const Duration(milliseconds: 250);

  Widget spriteTransition(Animation<double> animation, Widget child) =>
      FadeTransition(opacity: animation, child: child);

  /// Card shown over the stage when a conversation with a new `chapter` starts. Only called when
  /// [Conversation.chapter] is set. Null shows nothing.
  Widget? chapterCard(BuildContext context, Conversation conversation) => null;

  /// How long [chapterCard] stays on screen, fades included.
  Duration get chapterCardDuration => const Duration(milliseconds: 2200);

  /// The VN dialogue box around the typewriter [DialogueFrame.body].
  Widget dialogueFrame(BuildContext context, DialogueFrame frame) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 110),
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(225),
            border: Border.all(color: scheme.primary, width: 2),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 17, height: 1.4, fontWeight: FontWeight.w500, color: Colors.black87),
            child: frame.body,
          ),
        ),
        if (frame.speaker != null)
          Positioned(
            left: 14,
            top: -16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(16)),
              child: Text(
                frame.speaker!,
                style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  /// One option of a choice list. [index] is its position, handy for staggered entrances.
  /// [onTap] is null for locked choices. [Choice.chosen] marks options picked in an earlier playthrough.
  Widget choiceButton(BuildContext context, Choice choice, int index, VoidCallback? onTap, {required bool dark}) {
    final scheme = Theme.of(context).colorScheme;
    final background = dark ? Colors.black.withAlpha(150) : scheme.surfaceContainerHighest;
    final foreground = dark ? Colors.white : scheme.onSurface;
    return Material(
      color: choice.locked ? background.withAlpha(90) : background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: choice.locked ? Colors.transparent : scheme.primary.withAlpha(140)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (choice.locked) ...[
                Icon(Icons.lock_outline, size: 18, color: foreground.withAlpha(120)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TaggedText(
                  choice.text,
                  style: TextStyle(color: choice.locked ? foreground.withAlpha(120) : foreground, fontSize: 15),
                ),
              ),
              // Picked in an earlier playthrough.
              if (choice.chosen && !choice.locked) Icon(Icons.check, size: 18, color: foreground.withAlpha(150)),
            ],
          ),
        ),
      ),
    );
  }

  /// The VN overlay with the chapter label and the quick controls: backlog, auto, skip and menu,
  /// then back, quick save, quick load and hide. A null callback means the control is unavailable.
  Widget vnHud(BuildContext context, VnHud hud) {
    Widget toggle(String label, bool active, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(left: 4),
          child: FilterChip(
            label: Text(label),
            selected: active,
            onSelected: (_) => onTap(),
            visualDensity: VisualDensity.compact,
          ),
        );

    Widget button(String tooltip, IconData icon, VoidCallback? onPressed) => IconButton.filledTonal(
          tooltip: tooltip,
          onPressed: onPressed,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hud.label != null) Chip(visualDensity: VisualDensity.compact, label: Text(hud.label!)),
                const Spacer(),
                button("Backlog", Icons.history, hud.onBacklog),
                toggle("Auto", hud.autoMode, hud.onAuto),
                toggle("Skip", hud.skipMode, hud.onSkip),
                button("Menu", Icons.menu, hud.onMenu),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                button("Back", Icons.undo, hud.onBack),
                button("Quick save", Icons.bookmark_add_outlined, hud.onQuickSave),
                button("Quick load", Icons.bookmark_outline, hud.onQuickLoad),
                button("Hide", Icons.visibility_off_outlined, hud.onHide),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Provides a [StorySkin] to the story views below it.
class StorySkinScope extends InheritedWidget {
  final StorySkin skin;

  const StorySkinScope({super.key, required this.skin, required super.child});

  @override
  bool updateShouldNotify(StorySkinScope oldWidget) => skin != oldWidget.skin;
}

class DialogueFrame {
  final String? speaker;

  /// The typewriter text. Inherits the frame's [DefaultTextStyle].
  final Widget body;

  /// False while the text is still being typed out. Skins show a "next" indicator once it is done.
  final bool done;

  const DialogueFrame({required this.speaker, required this.body, required this.done});
}

class VnHud {
  /// Chapter and time of day, e.g. "Day 1 · 23:40".
  final String? label;
  final bool autoMode;
  final bool skipMode;
  final VoidCallback onBacklog;
  final VoidCallback onAuto;
  final VoidCallback onSkip;
  final VoidCallback onMenu;

  /// Rolls back to the previous line. Null when there is none.
  final VoidCallback? onBack;

  /// Null while saving is unavailable, e.g. during a replay.
  final VoidCallback? onQuickSave;
  final VoidCallback? onQuickLoad;

  /// Hides the dialogue box and the controls until the next tap.
  final VoidCallback onHide;

  const VnHud({
    required this.label,
    required this.autoMode,
    required this.skipMode,
    required this.onBacklog,
    required this.onAuto,
    required this.onSkip,
    required this.onMenu,
    required this.onHide,
    this.onBack,
    this.onQuickSave,
    this.onQuickLoad,
  });
}
