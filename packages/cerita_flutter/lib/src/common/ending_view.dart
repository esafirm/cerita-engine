import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../l10n/cerita_strings.dart';
import '../l10n/story_language.dart';
import '../meta/credits_screen.dart';

/// Ending summary overlay. Without an [ending] it shows [title], [CeritaStrings.theEnd] by default.
/// When [credits] roll after [ending], leaving the summary rolls them first (CE-08).
class EndingView extends StatefulWidget {
  final EndingItemType? ending;
  final String? title;
  final String? backLabel;
  final VoidCallback onTitle;
  final VoidCallback? onEndings;

  /// The story's credits, if any.
  final Credits? credits;

  const EndingView({
    super.key,
    this.ending,
    this.title,
    this.backLabel,
    required this.onTitle,
    this.onEndings,
    this.credits,
  });

  @override
  State<EndingView> createState() => _EndingViewState();
}

class _EndingViewState extends State<EndingView> {
  /// Where the player is going once the rolling credits are done.
  VoidCallback? _afterCredits;

  /// Runs [leave], after the credits when they roll after this ending.
  VoidCallback _leave(VoidCallback leave) => () {
        final ending = widget.ending;
        final rolls = ending != null && (widget.credits?.rollsAfter(ending.endingId) ?? false);
        if (rolls) {
          setState(() => _afterCredits = leave);
        } else {
          leave();
        }
      };

  @override
  Widget build(BuildContext context) {
    if (_afterCredits case final leave?) return RollingCredits(credits: widget.credits!, onDone: leave);
    final ending = widget.ending;
    final onEndings = widget.onEndings;
    final strings = StoryLanguage.of(context).strings;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: ColoredBox(
        color: Colors.black.withAlpha(215),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ending != null) EndingBadge(category: ending.category),
                  const SizedBox(height: 16),
                  Text(
                    ending?.title ?? widget.title ?? strings.theEnd,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  if (ending?.summary != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      ending!.summary!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 12,
                    children: [
                      if (onEndings != null)
                        OutlinedButton(
                          onPressed: _leave(onEndings),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                          child: Text(strings.allEndings),
                        ),
                      FilledButton(
                        onPressed: _leave(widget.onTitle),
                        child: Text(widget.backLabel ?? strings.backToTitle),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EndingBadge extends StatelessWidget {
  final EndingCategory category;

  const EndingBadge({super.key, required this.category});

  static Color colorOf(EndingCategory category) => switch (category) {
        EndingCategory.trueEnding => const Color(0xFFE0A100),
        EndingCategory.good => const Color(0xFF2E9E5B),
        EndingCategory.normal => const Color(0xFF5B7DB1),
        EndingCategory.bad => const Color(0xFFC0392B),
        EndingCategory.secret => const Color(0xFF8E44AD),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: colorOf(category), borderRadius: BorderRadius.circular(20)),
      child: Text(
        StoryLanguage.of(context).strings.endingBadge(category),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12),
      ),
    );
  }
}
