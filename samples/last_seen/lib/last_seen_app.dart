import 'dart:math';

import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';

import 'store/full_game.dart';
import 'title_screen.dart';
import 'ui/retro.dart';
import 'ui/retro_skin.dart';

class LastSeenApp extends StatelessWidget {
  final StorySetup setup;
  final StoryLanguage language;
  final FullGame fullGame;

  const LastSeenApp({super.key, required this.setup, required this.language, required this.fullGame});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Last Seen",
      debugShowCheckedModeBanner: false,
      theme: Retro.theme(),
      builder: (context, child) => StoryLanguageScope(
        language: language,
        child: StorySkinScope(
          skin: const RetroSkin(),
          child: _PhoneFrame(child: child!),
        ),
      ),
      home: TitleScreen(setup: setup, fullGame: fullGame),
    );
  }
}

/// On wide screens (web / desktop) the story is shown in a phone-sized frame, matching the portrait art.
class _PhoneFrame extends StatelessWidget {
  static const _width = 420.0;
  static const _maxHeight = 880.0;

  final Widget child;

  const _PhoneFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width < 600) return child;

    final height = min(media.size.height - 32, _maxHeight);
    return ColoredBox(
      color: Retro.night,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            width: _width,
            height: height,
            child: MediaQuery(
              data: media.copyWith(size: Size(_width, height), padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
