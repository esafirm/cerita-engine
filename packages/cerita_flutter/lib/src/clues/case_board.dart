import 'dart:async';

import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../common/media_widgets.dart';
import '../common/story_sheet.dart';
import '../common/tagged_text.dart';
import '../skin/story_skin.dart';
import '../story_controller.dart';
import '../l10n/story_language.dart';

/// The found clues grouped by chapter, newest chapter first, drawn with the skin's [StorySkin.clueGroupHeader]
/// and [StorySkin.clueCard]. Shared by the Case Board and the evidence picker.
class ClueBoardList extends StatelessWidget {
  final StoryController controller;
  final ValueChanged<Clue> onTap;

  /// Highlight clues not viewed yet. The picker doesn't.
  final bool highlightNew;

  final EdgeInsets padding;

  const ClueBoardList({
    super.key,
    required this.controller,
    required this.onTap,
    this.highlightNew = true,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    final skin = StorySkin.of(context);
    final strings = StoryLanguage.of(context).strings;
    final catalog = controller.clues;
    final found = {for (final clue in controller.foundClues) clue.id};
    final children = <Widget>[
      for (final group in catalog.groups)
        if (group.clues.where((clue) => found.contains(clue.id)).toList() case final shown when shown.isNotEmpty) ...[
          if (group.chapter != null || catalog.showCounts)
            skin.clueGroupHeader(
              context,
              ClueGroupHeader(
                chapter: group.chapter == null ? null : controller.clueText(group.chapter!),
                found: shown.length,
                total: catalog.showCounts ? group.clues.length : null,
              ),
            ),
          for (final clue in shown)
            skin.clueCard(
              context,
              ClueCard(
                clue: clue,
                title: controller.clueText(clue.title),
                image: controller.clueImage(clue),
                isKey: clue.isKey,
                isNew: highlightNew && controller.isClueNew(clue),
                onTap: () => onTap(clue),
              ),
            ),
        ],
    ];
    if (children.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(strings.noCluesYet)));
    }
    return ListView(padding: padding, children: children);
  }
}

/// A clue's title, image and full description in the active language. Tapping the image opens it full
/// screen. [actions] go below.
class ClueDetail extends StatelessWidget {
  final Clue clue;
  final StoryController controller;
  final List<Widget> actions;

  /// Shows the clue's title. Off in a sheet whose header already names the clue.
  final bool showTitle;

  const ClueDetail({
    super.key,
    required this.clue,
    required this.controller,
    this.actions = const [],
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = StoryLanguage.of(context).strings;
    final title = controller.clueText(clue.title);
    final description = clue.description == null ? null : controller.clueText(clue.description!);
    final image = controller.clueImage(clue);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle)
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
              if (clue.isKey) Icon(Icons.star, color: theme.colorScheme.tertiary, semanticLabel: strings.keyClue),
            ],
          )
        else if (clue.isKey)
          Row(
            children: [
              Icon(Icons.star, size: 18, color: theme.colorScheme.tertiary),
              const SizedBox(width: 6),
              Text(strings.keyClue, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.tertiary)),
            ],
          ),
        if (image != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Builder(
              builder: (thumbnail) => GestureDetector(
                onTap: () => ImageViewerPage.open(context, image, caption: title, from: thumbnail),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: Image.asset(image, width: double.infinity, fit: BoxFit.cover),
                      ),
                      // A tap opens the whole picture.
                      const Positioned(
                        right: 8,
                        bottom: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.open_in_full, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (description != null)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text(description, style: theme.textTheme.bodyLarge)),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, spacing: 8, children: actions),
          ),
      ],
    );
  }
}

/// The Case Board: every clue found in this playthrough. Open it with [open].
class CaseBoardScreen extends StatefulWidget {
  final StoryController controller;

  /// Opens this clue's detail right away, e.g. from the clue notification.
  final Clue? initialClue;

  const CaseBoardScreen({super.key, required this.controller, this.initialClue});

  /// Pushes the board. The story holds until it closes, and then the clues it showed count as viewed.
  static Future<void> open(BuildContext context, StoryController controller, {Clue? clue}) async {
    final shown = controller.foundClues;
    controller.holdStory(true);
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CaseBoardScreen(controller: controller, initialClue: clue),
    ));
    controller
      ..markCluesViewed(shown)
      ..holdStory(false);
  }

  @override
  State<CaseBoardScreen> createState() => _CaseBoardScreenState();
}

class _CaseBoardScreenState extends State<CaseBoardScreen> {
  @override
  void initState() {
    super.initState();
    final clue = widget.initialClue;
    if (clue != null) WidgetsBinding.instance.addPostFrameCallback((_) => _openClue(clue));
  }

  void _openClue(Clue clue) {
    if (!mounted) return;
    StorySheet.show<void>(
      context,
      title: widget.controller.clueText(clue.title),
      icon: Icons.search,
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: ClueDetail(clue: clue, controller: widget.controller, showTitle: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(StoryLanguage.of(context).strings.caseBoard)),
      body: StorySkin.of(context).caseBoardBackground(
        context,
        ClueBoardList(controller: widget.controller, onTap: _openClue),
      ),
    );
  }
}

/// The Case Board in picker mode, for an evidence question: the prompt, an optional countdown and the found
/// clues. Tapping a clue shows its detail with Present and Back, so a stray tap can't answer.
class EvidencePicker extends StatefulWidget {
  final StoryController controller;
  final EvidenceItemType item;
  final bool dark;

  const EvidencePicker({super.key, required this.controller, required this.item, this.dark = false});

  @override
  State<EvidencePicker> createState() => _EvidencePickerState();
}

class _EvidencePickerState extends State<EvidencePicker> with SingleTickerProviderStateMixin {
  AnimationController? _countdown;
  Clue? _selected;

  @override
  void initState() {
    super.initState();
    final timeout = widget.item.timeoutMs;
    if (timeout != null && timeout > 0) {
      _countdown = AnimationController(vsync: this, duration: Duration(milliseconds: timeout))
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.controller.evidenceTimedOut();
        })
        ..forward();
    }
  }

  @override
  void dispose() {
    _countdown?.dispose();
    super.dispose();
  }

  void _present(Clue clue) {
    _countdown?.stop();
    widget.controller.present(clue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = _selected;
    final countdown = _countdown;
    final controller = widget.controller;
    final strings = StoryLanguage.of(context).strings;

    return StorySkin.of(context).caseBoardBackground(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: TaggedText(widget.item.text, style: theme.textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(strings.chooseEvidence, style: theme.textTheme.labelMedium),
          ),
          if (countdown != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: AnimatedBuilder(
                animation: countdown,
                builder: (context, _) => LinearProgressIndicator(
                  value: 1 - countdown.value,
                  minHeight: 6,
                  color: scheme.error,
                  backgroundColor: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          Expanded(
            child: selected == null
                ? ClueBoardList(
                    controller: controller,
                    highlightNew: false,
                    onTap: (clue) => setState(() => _selected = clue),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ClueDetail(
                      clue: selected,
                      controller: controller,
                      actions: [
                        TextButton(
                          onPressed: () => setState(() => _selected = null),
                          child: Text(strings.back),
                        ),
                        FilledButton(
                          onPressed: () => _present(selected),
                          child: Text(strings.present),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Shows a [StorySkin.clueNotification] at the top of [child] for each clue the story finds, one at a time.
/// Tapping one opens the clue on the Case Board.
///
/// None shows during an evidence question: it would cover the picker's prompt and countdown, and open the
/// board the question hides. Notifications still queued when the question comes are dropped. Their clues stay
/// new, so the picker lists them and the board's badge counts them afterwards.
class ClueNotifications extends StatefulWidget {
  final StoryController controller;
  final Widget child;

  static const duration = Duration(seconds: 3);

  const ClueNotifications({super.key, required this.controller, required this.child});

  @override
  State<ClueNotifications> createState() => _ClueNotificationsState();
}

class _ClueNotificationsState extends State<ClueNotifications> {
  final List<Clue> _queue = [];
  late final StreamSubscription<Clue> _subscription;
  Timer? _timer;

  StoryController get _controller => widget.controller;

  bool get _evidenceAsked => _controller.phase == StoryPhase.choice && _controller.current is EvidenceItemType;

  @override
  void initState() {
    super.initState();
    _subscription = _controller.cluesFound.listen((clue) {
      if (_evidenceAsked) return;
      setState(() => _queue.add(clue));
      if (_queue.length == 1) _schedule();
    });
    _controller.addListener(_onStoryChanged);
  }

  void _onStoryChanged() {
    if (!_evidenceAsked || _queue.isEmpty) return;
    _timer?.cancel();
    setState(_queue.clear);
  }

  void _schedule() {
    _timer?.cancel();
    if (_queue.isEmpty) return;
    _timer = Timer(ClueNotifications.duration, _dismiss);
  }

  void _dismiss() {
    if (!mounted || _queue.isEmpty) return;
    setState(() => _queue.removeAt(0));
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.removeListener(_onStoryChanged);
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clue = _evidenceAsked ? null : _queue.firstOrNull;
    final controller = widget.controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 12,
          right: 12,
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween(begin: const Offset(0, -1.5), end: Offset.zero).animate(animation),
                child: child,
              ),
              child: clue == null
                  ? const SizedBox.shrink()
                  : Padding(
                      key: ValueKey(clue.id),
                      padding: const EdgeInsets.only(top: 8),
                      child: StorySkin.of(context).clueNotification(
                        context,
                        ClueNotice(
                          clue: clue,
                          title: controller.clueText(clue.title),
                          image: controller.clueImage(clue),
                          onTap: () {
                            _dismiss();
                            CaseBoardScreen.open(context, controller, clue: clue);
                          },
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
