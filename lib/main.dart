import 'package:flutter/material.dart';
import 'package:fsse/demo/demo_app.dart';
import 'package:fsse/src/presentation/story_setup.dart';

void main() {
  runApp(DemoApp(setup: StorySetup.assets()));
}
