import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'last_seen_app.dart';
import 'store/full_game.dart';
import 'store/paywall.dart';
import 'store/revenuecat_store.dart';
import 'ui/retro.dart';

/// Playtest builds pass `--dart-define=LAST_SEEN_TESTER=true` to play every day without buying. Debug builds do by
/// default; pass `false` to see the paywall. Store builds never set it.
const _tester = bool.fromEnvironment("LAST_SEEN_TESTER", defaultValue: kDebugMode);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = SharedPrefsStoryStorage();
  final fullGame = FullGame(
    store: RevenueCatStore(),
    prefs: await SharedPreferences.getInstance(),
    storage: storage,
    tester: _tester,
  );
  // Before anything can write progress: the grandfather check reads what version 1.0.0 left.
  await fullGame.load();

  // The developer panel (in-game menu → Developer) is for writing the story, not for players.
  final setup = StorySetup.assets(
    developer: kDebugMode,
    storage: storage,
    // Day 3 onwards needs the full game, wherever the story comes from: a new game, a save or the chapter list.
    gate: fullGame.allows,
    gateBuilder: (context, request) => Paywall(
      fullGame: fullGame,
      chapter: StoryLanguage.of(context).maybe(request.conversation.chapterText),
      overStory: true,
      onUnlocked: () {
        final reopen = request.reopen;
        reopen == null ? request.leave() : reopen();
      },
      onLeave: request.leave,
    ),
  );
  final language = StoryLanguage();
  await language.load(setup);
  UiSounds.instance = UiSounds(setup);
  // A game, not an app: no status or navigation bar until the player swipes for them.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(LastSeenApp(setup: setup, language: language, fullGame: fullGame));
}
