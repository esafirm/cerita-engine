import 'dart:math';

import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:cerita_ui/cerita_ui.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart';

class DemoApp extends StatelessWidget {
  final StorySetup setup;

  const DemoApp({super.key, required this.setup});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Cerita Engine Demo",
      debugShowCheckedModeBanner: false,
      theme: CeritaTheme.dark(),
      builder: (context, child) => StorySkinScope(skin: const AnimeVnSkin(), child: _PhoneFrame(child: child!)),
      home: HomeScreen(setup: setup),
    );
  }
}

/// On wide screens (web / desktop) the story is shown in a phone-sized frame,
/// matching the portrait art and the messenger layout.
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
      color: const Color(0xFF1C1B1F),
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
