import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';

import 'retro.dart';

/// The in-game look of Last Seen ([Retro]): a framed dialogue window with a name tab, choice windows that
/// invert when pressed, palette-step fades, and the quick controls folded into one MENU window.
class RetroSkin extends StorySkin {
  const RetroSkin();

  static const _fade = SteppedCurve(5);

  @override
  Duration get sceneTransitionDuration => const Duration(milliseconds: 900);

  @override
  Widget sceneTransition(SceneMode mode, Animation<double> animation, Widget child) {
    // Fade to black and back in palette steps. The outgoing scene is gone by the midpoint.
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.5, 1, curve: _fade),
      reverseCurve: const Interval(0.5, 1, curve: _fade),
    );
    return FadeTransition(opacity: fade, child: child);
  }

  @override
  Duration get backgroundTransitionDuration => const Duration(milliseconds: 600);

  @override
  Widget backgroundTransition(Animation<double> animation, Widget child) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: _fade),
    child: child,
  );

  @override
  Duration get spriteTransitionDuration => const Duration(milliseconds: 240);

  @override
  Widget spriteTransition(Animation<double> animation, Widget child) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: const SteppedCurve(3)),
    child: child,
  );

  @override
  Duration get chapterCardDuration => const Duration(milliseconds: 2600);

  @override
  Widget? chapterCard(BuildContext context, Conversation conversation) =>
      _ChapterCard(chapter: conversation.chapter!, title: conversation.title);

  @override
  Widget dialogueFrame(BuildContext context, DialogueFrame frame) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        RetroWindow(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: SizedBox(
              width: double.infinity,
              child: DefaultTextStyle.merge(style: Retro.text.copyWith(fontSize: 17), child: frame.body),
            ),
          ),
        ),
        if (frame.speaker case final speaker?) Positioned(left: 14, top: -18, child: _NameTab(speaker)),
        if (frame.done)
          const Positioned(
            right: 16,
            bottom: 10,
            child: Blink(
              period: Duration(milliseconds: 700),
              child: Text(
                "▼",
                style: TextStyle(fontFamily: Retro.font, color: Retro.accent, fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget choiceButton(BuildContext context, Choice choice, int index, VoidCallback? onTap, {required bool dark}) {
    return _ChoiceButton(
      choice: choice,
      onTap: onTap,
      marker: choice.memoryMarker && !choice.locked ? memoryMarker(context, choice, dark: dark) : null,
    );
  }

  @override
  Widget vnHud(BuildContext context, VnHud hud) {
    final strings = StoryLanguage.of(context).strings;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: hud.label == null
                    ? null
                    : RetroWindow(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        child: Text(
                          hud.label!.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Retro.text.copyWith(fontSize: 12, height: 1.3, letterSpacing: 1.4),
                        ),
                      ),
              ),
            ),
            if (hud.autoMode || hud.skipMode) ...[
              const SizedBox(width: 8),
              _HudTag(
                hud.skipMode ? strings.skip.toUpperCase() : strings.auto.toUpperCase(),
                onTap: hud.skipMode ? hud.onSkip : hud.onAuto,
              ),
            ],
            const SizedBox(width: 8),
            _HudTag(
              hud.newClues > 0 ? "${strings.menu.toUpperCase()} !" : strings.menu.toUpperCase(),
              alert: hud.newClues > 0,
              onTap: () {
                UiSounds.instance?.confirm();
                _QuickMenu.show(context, hud);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NameTab extends StatelessWidget {
  final String name;

  const _NameTab(this.name);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Retro.night,
        border: Border.all(color: Retro.frame, width: 2),
        boxShadow: const [Retro.shadow],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Text(
          name,
          style: Retro.text.copyWith(color: Retro.accent, fontSize: 15, height: 1.4, letterSpacing: 1.2),
        ),
      ),
    );
  }
}

/// A choice window. Pressing it inverts it and points the cursor at it.
class _ChoiceButton extends StatefulWidget {
  final Choice choice;
  final VoidCallback? onTap;
  final Widget? marker;

  const _ChoiceButton({required this.choice, required this.onTap, this.marker});

  @override
  State<_ChoiceButton> createState() => _ChoiceButtonState();
}

class _ChoiceButtonState extends State<_ChoiceButton> {
  bool _pressed = false;

  void _press(bool pressed) {
    if (widget.onTap == null || pressed == _pressed) return;
    if (pressed) UiSounds.instance?.cursor();
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final choice = widget.choice;
    final locked = choice.locked;
    final foreground = locked ? Retro.dim : (_pressed ? Retro.night : Retro.frame);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(true),
      onTapCancel: () => _press(false),
      onTapUp: (_) => _press(false),
      onTap: widget.onTap == null
          ? null
          : () {
              UiSounds.instance?.confirm();
              widget.onTap!();
            },
      child: RetroWindow(
        fill: _pressed ? Retro.frame : Retro.ink,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: locked
                  ? Text("×", style: Retro.text.copyWith(color: Retro.dim, height: 1.3))
                  : (_pressed
                        ? const Align(
                            alignment: Alignment.centerLeft,
                            child: RetroCursor(color: Retro.night),
                          )
                        : null),
            ),
            if (widget.marker case final marker?) ...[marker, const SizedBox(width: 8)],
            Expanded(
              child: TaggedText(choice.text, style: Retro.text.copyWith(color: foreground, fontSize: 15, height: 1.4)),
            ),
            // Picked in an earlier playthrough.
            if (choice.chosen && !locked) Text("✓", style: Retro.text.copyWith(color: foreground, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

class _HudTag extends StatelessWidget {
  final String label;
  final bool alert;
  final VoidCallback onTap;

  const _HudTag(this.label, {required this.onTap, this.alert = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: RetroWindow(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        fill: alert ? Retro.accent : Retro.ink,
        child: Text(
          label,
          style: Retro.text.copyWith(
            color: alert ? Retro.night : Retro.frame,
            fontSize: 13,
            height: 1.3,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

/// The quick controls in one window under the MENU tag.
class _QuickMenu extends StatelessWidget {
  final VnHud hud;

  const _QuickMenu(this.hud);

  static void show(BuildContext context, VnHud hud) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "menu",
      barrierColor: Colors.black38,
      transitionDuration: Duration.zero,
      pageBuilder: (context, _, _) => _QuickMenu(hud),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = StoryLanguage.of(context).strings;
    final entries = <(String, VoidCallback?)>[
      (strings.log, hud.onBacklog),
      ("${strings.auto}${hud.autoMode ? " ●" : ""}", hud.onAuto),
      ("${strings.skip}${hud.skipMode ? " ●" : ""}", hud.onSkip),
      (strings.back, hud.onBack),
      (strings.quickSaveShort, hud.onQuickSave),
      (strings.quickLoadShort, hud.onQuickLoad),
      if (hud.onCaseBoard case final onCaseBoard?)
        ([strings.caseBoardShort, if (hud.newClues > 0) "(${hud.newClues})"].join(" "), onCaseBoard),
      (strings.hide, hud.onHide),
      (StoryLanguage.of(context).locale == "en" ? "System" : "Sistem", hud.onMenu),
    ];

    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 46, 10, 0),
          child: SizedBox(
            width: 190,
            child: RetroWindow(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (label, onTap) in entries)
                      _MenuRow(
                        label.toUpperCase(),
                        onTap: onTap == null
                            ? null
                            : () {
                                UiSounds.instance?.confirm();
                                Navigator.of(context).pop();
                                onTap();
                              },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;

  const _MenuRow(this.label, {required this.onTap});

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: _pressed ? const Align(alignment: Alignment.centerLeft, child: RetroCursor()) : null,
            ),
            Text(
              widget.label,
              style: Retro.text.copyWith(color: enabled ? Retro.frame : Retro.dim, height: 1.2, letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final String chapter;
  final String? title;

  const _ChapterCard({required this.chapter, this.title});

  @override
  Widget build(BuildContext context) {
    final card = chapter.toUpperCase();
    return ColoredBox(
      color: Retro.night,
      child: Center(
        // The chapter name types out, one character per step.
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1100),
          builder: (context, value, _) => RetroWindow(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  card.substring(0, (card.length * value).round()).padRight(card.length),
                  style: Retro.text.copyWith(fontSize: 26, letterSpacing: 6, height: 1.3),
                ),
                if (title != null) ...[
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: value < 1 ? 0 : 1,
                    child: Text(title!, style: Retro.text.copyWith(color: Retro.accent, fontSize: 14)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
