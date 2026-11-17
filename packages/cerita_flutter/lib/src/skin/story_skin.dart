import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../common/story_sheet.dart';
import '../common/tagged_text.dart';
import '../l10n/story_language.dart';
import '../meta/credits_screen.dart';

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

  /// The story's credits, on the Credits screen and rolling after an ending ([rolling], drawn over black).
  /// Read text in the active language with `StoryLanguage.of(context)`.
  Widget credits(BuildContext context, Credits credits, {required bool rolling}) =>
      CreditsList(credits: credits, rolling: rolling);

  /// How narration lines differ from spoken ones, in the dialogue box, the NVL page, the backlog and chat. Merged
  /// over the surrounding text style. Italic by default; override for fonts without an italic, such as dot fonts.
  TextStyle get narrationStyle => const TextStyle(fontStyle: FontStyle.italic);

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
  /// Unlocked options with [Choice.memoryMarker] carry the [memoryMarker].
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
              if (choice.memoryMarker && !choice.locked)
                if (memoryMarker(context, choice, dark: dark) case final marker?)
                  Padding(padding: const EdgeInsets.only(left: 8), child: marker),
              // Picked in an earlier playthrough.
              if (choice.chosen && !choice.locked) Icon(Icons.check, size: 18, color: foreground.withAlpha(150)),
            ],
          ),
        ),
      ),
    );
  }

  /// Marker on an available choice the author flagged `memory_marker`, so the player notices what past
  /// runs unlocked. [choiceButton] places it. Override to restyle it, or return null to hide it.
  Widget? memoryMarker(BuildContext context, Choice choice, {required bool dark}) {
    final color = dark ? Colors.amberAccent : Theme.of(context).colorScheme.tertiary;
    final label = StoryLanguage.of(context).strings.memoryMarker;
    return Icon(Icons.auto_awesome, size: 16, color: color.withAlpha(200), semanticLabel: label);
  }

  /// A bottom sheet of the story (see [StorySheet]): the menu, the backlog, a clue's detail. The default is a
  /// raised panel with a handle, the title with its icon, a close button and a rule under the header.
  Widget sheet(BuildContext context, StorySheetFrame frame) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * StorySheet.maxHeightFactor;
    final title = frame.title;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight, minHeight: frame.expand ? maxHeight : 0),
      child: Material(
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: scheme.outlineVariant.withAlpha(120)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: scheme.outline, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              if (title != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
                  child: Row(
                    children: [
                      if (frame.icon case final icon?) ...[
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: scheme.secondaryContainer,
                          child: Icon(icon, size: 20, color: scheme.onSecondaryContainer),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                        icon: const Icon(Icons.close),
                        onPressed: frame.onClose,
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, indent: 20, endIndent: 20, color: scheme.outlineVariant),
              ],
              if (frame.expand) Expanded(child: frame.body) else Flexible(child: frame.body),
            ],
          ),
        ),
      ),
    );
  }

  /// Backdrop of the Case Board and the evidence picker, behind the clue list. Override for a cork board, a
  /// notebook or a case file.
  Widget caseBoardBackground(BuildContext context, Widget child) =>
      ColoredBox(color: Theme.of(context).colorScheme.surface, child: child);

  /// A chapter heading on the Case Board. [ClueGroupHeader.total] is set when the story shows counts.
  Widget clueGroupHeader(BuildContext context, ClueGroupHeader header) {
    final theme = Theme.of(context);
    final strings = StoryLanguage.of(context).strings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              header.chapter ?? "",
              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          if (header.total case final total?)
            Text(strings.cluesFound(header.found, total), style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }

  /// One clue on the Case Board or in the evidence picker.
  Widget clueCard(BuildContext context, ClueCard card) {
    final scheme = Theme.of(context).colorScheme;
    final strings = StoryLanguage.of(context).strings;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: card.isNew ? scheme.primary : Colors.transparent, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: card.onTap,
        leading: SizedBox.square(
          dimension: 48,
          child: card.image == null
              ? Icon(Icons.search, color: scheme.primary)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(card.image!, fit: BoxFit.cover),
                ),
        ),
        title: Text(card.title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (card.isNew)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Chip(label: Text(strings.newClue), visualDensity: VisualDensity.compact),
              ),
            if (card.isKey) Icon(Icons.star, color: scheme.tertiary, semanticLabel: strings.keyClue),
          ],
        ),
      ),
    );
  }

  /// The "Clue found" notification at the top of the story. Tapping it calls [ClueNotice.onTap].
  Widget clueNotification(BuildContext context, ClueNotice notice) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: notice.onTap,
        leading: notice.image == null
            ? const Icon(Icons.search)
            : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(notice.image!, width: 40, height: 40, fit: BoxFit.cover),
              ),
        title: Text(StoryLanguage.of(context).strings.clueFound(notice.title)),
      ),
    );
  }

  /// The VN overlay with the chapter label and the quick controls: backlog, auto, skip and menu,
  /// then back, quick save, quick load, hide and, in stories with clues, the Case Board. A null callback means
  /// the control is unavailable.
  /// It is placed at the top of the stage with the full width and its own height, and gets no bottom inset. While
  /// the evidence picker is open, the picker takes the space below it.
  /// Skins translate their own text: `StoryLanguage.of(context)` has the locale and the engine strings.
  Widget vnHud(BuildContext context, VnHud hud) {
    final strings = StoryLanguage.of(context).strings;
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
                // A long chapter name is cut short rather than pushing the buttons off screen.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: hud.label == null
                        ? null
                        : Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(hud.label!, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                  ),
                ),
                button(strings.backlog, Icons.history, hud.onBacklog),
                toggle(strings.auto, hud.autoMode, hud.onAuto),
                toggle(strings.skip, hud.skipMode, hud.onSkip),
                button(strings.menu, Icons.menu, hud.onMenu),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                button(strings.back, Icons.undo, hud.onBack),
                button(strings.quickSave, Icons.bookmark_add_outlined, hud.onQuickSave),
                button(strings.quickLoad, Icons.bookmark_outline, hud.onQuickLoad),
                button(strings.hide, Icons.visibility_off_outlined, hud.onHide),
                if (hud.onCaseBoard case final onCaseBoard?)
                  Badge(
                    isLabelVisible: hud.newClues > 0,
                    label: Text("${hud.newClues}"),
                    child: button(strings.caseBoard, Icons.push_pin_outlined, onCaseBoard),
                  ),
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

  /// Opens the Case Board. Null in stories without clues and while the evidence picker is open.
  final VoidCallback? onCaseBoard;

  /// Found clues not viewed on the board yet, for a badge.
  final int newClues;

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
    this.onCaseBoard,
    this.newClues = 0,
  });
}

/// A chapter heading on the Case Board, see [StorySkin.clueGroupHeader].
class ClueGroupHeader {
  /// Null for the clues without a chapter.
  final String? chapter;
  final int found;

  /// How many clues the chapter has, when the story shows counts (`show_counts`).
  final int? total;

  const ClueGroupHeader({required this.chapter, required this.found, this.total});
}

/// One clue on the Case Board or in the evidence picker, see [StorySkin.clueCard].
class ClueCard {
  final Clue clue;
  final String title;

  /// Asset path of the clue image.
  final String? image;
  final bool isKey;

  /// Found but not viewed on the board yet.
  final bool isNew;
  final VoidCallback onTap;

  const ClueCard({
    required this.clue,
    required this.title,
    required this.image,
    required this.isKey,
    required this.isNew,
    required this.onTap,
  });
}

/// A "Clue found" notification, see [StorySkin.clueNotification].
class ClueNotice {
  final Clue clue;
  final String title;

  /// Asset path of the clue image.
  final String? image;

  /// Opens the clue on the Case Board.
  final VoidCallback onTap;

  const ClueNotice({required this.clue, required this.title, required this.image, required this.onTap});
}
