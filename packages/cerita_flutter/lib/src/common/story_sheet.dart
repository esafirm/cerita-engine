import 'package:flutter/material.dart';

import '../skin/story_skin.dart';

/// What a story sheet shows, for [StorySkin.sheet] to frame.
class StorySheetFrame {
  /// The header. Null leaves the header out, for a body with its own.
  final String? title;
  final IconData? icon;
  final Widget body;

  /// Takes the full height a sheet may have, for a body that scrolls by itself and would otherwise jump in size.
  /// Else the sheet is as tall as its body, up to that height, and the body should scroll when it is taller.
  final bool expand;

  /// Closes the sheet, for the header's close button.
  final VoidCallback onClose;

  const StorySheetFrame({required this.body, required this.onClose, this.title, this.icon, this.expand = false});
}

/// The engine's bottom sheet: the in-game menu, the backlog, a clue's detail and the developer tools all open in
/// it, so they share one frame (handle, header, close button) that the [StorySkin] can restyle.
abstract final class StorySheet {
  /// The share of the screen height a sheet may take.
  static const maxHeightFactor = 0.88;

  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    String? title,
    IconData? icon,
    bool expand = false,
  }) {
    final skin = StorySkin.of(context);
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // The skin draws the whole sheet, its handle too.
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: Colors.black54,
      builder: (sheetContext) => skin.sheet(
        sheetContext,
        StorySheetFrame(
          title: title,
          icon: icon,
          expand: expand,
          body: builder(sheetContext),
          onClose: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
  }
}

/// A big square button for a sheet's main actions, laid out in a row of a few: an icon over a short label, and an
/// optional count badge (new clues).
class StorySheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  const StorySheetAction({super.key, required this.icon, required this.label, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text("$badge"),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
