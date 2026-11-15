import 'dart:convert';
import 'dart:io';

import 'package:cerita_tools/cerita_tools.dart';
import 'package:path/path.dart' as p;

/// The Wrong Number story written as a script.
const wrongNumberDir = "test/fixtures/wrong_number";

/// The hand-written Wrong Number JSON the script must compile to.
final exampleStoryDir = p.join("..", "..", "example", "assets", "story");

StoryProject loadWrongNumber() => StoryProject.load(wrongNumberDir);

/// The hand-written story files, parsed.
Map<String, Object?> exampleStoryJson() {
  final files = Directory(exampleStoryDir).listSync().whereType<File>().where((f) => f.path.endsWith(".json"));
  return {for (final file in files) p.basename(file.path): jsonDecode(file.readAsStringSync())};
}

/// A minimal story in memory. [scripts] maps file names to script text.
StoryProject story(
  Map<String, String> scripts, {
  String config = "source_locale: en\n",
  String? profiles,
  String? channels,
  String? clues,
  Set<String>? assets,
}) =>
    StoryProject.fromSources(
      config: config,
      profiles: profiles ??
          "nora:\n  name: Nora\n  expressions:\n    open: nora_open.png\n    smile: nora_smile.png\n",
      channels: channels,
      clues: clues,
      scripts: scripts,
      assetFiles: assets,
    );
