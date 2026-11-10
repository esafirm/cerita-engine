import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../common/avatar.dart';
import '../common/media_widgets.dart';
import '../story_controller.dart';
import '../story_setup.dart';

/// Renders one transcript entry: incoming / outgoing bubble, media bubble or system pill.
class MessageBubble extends StatelessWidget {
  final TranscriptEntry entry;
  final StoryController controller;
  final StorySetup setup;
  final bool showSender;

  const MessageBubble({
    super.key,
    required this.entry,
    required this.controller,
    required this.setup,
    this.showSender = true,
  });

  static bool isVisible(TranscriptEntry entry) {
    final item = entry.itemType;
    return entry.isPlayer || item is TextItemType || item is NarrationItemType || item is MediaItemType;
  }

  static String? _senderId(TranscriptEntry entry) =>
      entry.isPlayer ? ProfileInfo.playerId : entry.itemType?.getProfileInfo()?.id;

  static bool sameSender(TranscriptEntry a, TranscriptEntry b) {
    final id = _senderId(a);
    return id != null && id == _senderId(b);
  }

  @override
  Widget build(BuildContext context) {
    final item = entry.itemType;
    if (item is NarrationItemType) return _SystemPill(item: item);

    final profile = item == null ? null : controller.profileOf(item);
    final outgoing = entry.isPlayer || (profile?.isPlayer ?? false);
    final scheme = Theme.of(context).colorScheme;
    final bubbleColor = outgoing ? scheme.primary : scheme.surfaceContainerHighest;
    final textColor = outgoing ? scheme.onPrimary : scheme.onSurface;

    final content = switch (item) {
      MediaItemType() => _MediaContent(item: item, setup: setup, controller: controller, textColor: textColor),
      _ => Text(entry.playerText ?? item?.getText() ?? "", style: TextStyle(color: textColor, fontSize: 15)),
    };

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
      padding: item is MediaItemType ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(outgoing ? 18 : 4),
          bottomRight: Radius.circular(outgoing ? 4 : 18),
        ),
      ),
      child: content,
    );

    if (outgoing) {
      return Padding(
        padding: EdgeInsets.only(top: showSender ? 10 : 3, left: 48),
        child: Align(alignment: Alignment.centerRight, child: bubble),
      );
    }

    final avatar = profile?.avatar;
    return Padding(
      padding: EdgeInsets.only(top: showSender ? 10 : 3, right: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 36,
            child: showSender
                ? StoryAvatar(
                    asset: avatar == null ? null : setup.config.avatar(avatar),
                    name: profile?.name ?? "",
                    radius: 15,
                  )
                : null,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showSender && profile != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 2),
                    child: Text(profile.name, style: TextStyle(fontSize: 12, color: scheme.primary)),
                  ),
                bubble,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemPill extends StatelessWidget {
  final NarrationItemType item;

  const _SystemPill({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timestamp = item.style == NarrationStyle.timestamp;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: timestamp ? scheme.secondaryContainer : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            item.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: timestamp ? FontWeight.w600 : FontWeight.normal,
              fontStyle: item.style == NarrationStyle.narration ? FontStyle.italic : null,
              color: timestamp ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaContent extends StatelessWidget {
  final MediaItemType item;
  final StorySetup setup;
  final StoryController controller;
  final Color textColor;

  const _MediaContent({required this.item, required this.setup, required this.controller, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final path = setup.mediaPath(item);
    final caption = item.caption;
    final media = switch (item.mediaType) {
      MediaType.image || MediaType.cg => GestureDetector(
          onTap: () => ImageViewerPage.open(context, path, caption: caption),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Hero(tag: path, child: Image.asset(path, width: 220, fit: BoxFit.cover)),
          ),
        ),
      MediaType.audio => VoiceNotePlayer(
          asset: path,
          transcript: item.transcript,
          audio: controller.audio,
          color: textColor,
        ),
      MediaType.video => SizedBox(
          width: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: VideoPreview(asset: path, caption: caption, audio: controller.audio),
          ),
        ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        media,
        if (caption != null && item.mediaType != MediaType.audio)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Text(caption, style: TextStyle(color: textColor)),
          ),
      ],
    );
  }
}

/// Animated "..." bubble shown while [StoryPhase.typing].
class TypingBubble extends StatefulWidget {
  final Profile? profile;
  final StorySetup setup;

  const TypingBubble({super.key, required this.profile, required this.setup});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _dots =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = widget.profile?.avatar;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          StoryAvatar(
            asset: avatar == null ? null : widget.setup.config.avatar(avatar),
            name: widget.profile?.name ?? "",
            radius: 15,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
            child: AnimatedBuilder(
              animation: _dots,
              builder: (context, _) => Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.onSurfaceVariant.withAlpha(((_dots.value * 3 - i) % 3) < 1 ? 230 : 80),
                      ),
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
