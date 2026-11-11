import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'demo_app.dart';

void main() {
  // The developer panel (in-game menu → Developer) is for writing the story, not for players.
  runApp(DemoApp(setup: StorySetup.assets(developer: kDebugMode)));
}
