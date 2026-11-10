import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

/// Ending summary overlay. Without an [ending] it shows a plain "The End".
class EndingView extends StatelessWidget {
  final EndingItemType? ending;
  final VoidCallback onTitle;
  final VoidCallback? onEndings;

  const EndingView({super.key, this.ending, required this.onTitle, this.onEndings});

  @override
  Widget build(BuildContext context) {
    final ending = this.ending;
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
                    ending?.title ?? "The End",
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
                          onPressed: onEndings,
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                          child: const Text("All endings"),
                        ),
                      FilledButton(onPressed: onTitle, child: const Text("Back to title")),
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
        "${category.key} ENDING",
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12),
      ),
    );
  }
}
