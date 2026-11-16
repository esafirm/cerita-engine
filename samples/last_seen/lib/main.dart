import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'last_seen_app.dart';
import 'ui/retro.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The developer panel (in-game menu → Developer) is for writing the story, not for players.
  final setup = StorySetup.assets(developer: kDebugMode);
  final language = StoryLanguage();
  await language.load(setup);
  UiSounds.instance = UiSounds(setup);
  // A game, not an app: no status or navigation bar until the player swipes for them.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(LastSeenApp(setup: setup, language: language));
}
