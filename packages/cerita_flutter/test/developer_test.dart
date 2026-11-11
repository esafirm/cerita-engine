import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Map<String, dynamic> _text(String text, {String profile = "nora:0"}) =>
    {"type": "TEXT", "text": text, "profile": profile};

Map<String, Map<String, dynamic>> _files() => {
      "index": {
        "conversation_id": "cvn",
        "chapter": "Prologue",
        "scene": {"mode": "VN"},
        "conversations": [
          _text("One"),
          _text("Two"),
          {"type": "JUMP", "target": "day2"},
        ],
      },
      "day2": {
        "conversation_id": "cvn",
        "chapter": "Day 2",
        "scene": {"mode": "VN"},
        "conversations": [
          _text("Morning"),
          {"type": "TEXT", "id": "cafe", "text": "At the café, {{NAME}}", "profile": "ghost:0"},
        ],
      },
    };

void main() {
  setUp(mockAudioChannels);

  Future<(StoryController, Map<String, Map<String, dynamic>>)> pumpStory(WidgetTester tester,
      {bool developer = true}) async {
    final files = _files();
    final setup = StorySetup(
      config: const LoaderConfig(),
      loader: FakeEngineLoader(files),
      storage: InMemoryStoryStorage(),
      audio: SilentAudio.new,
      developer: developer,
    );
    await tester.pumpWidget(MaterialApp(home: StoryScreen(setup: setup)));
    await tester.pumpAndSettle();
    return (tester.widget<VnStage>(find.byType(VnStage).last).controller, files);
  }

  Future<void> openDeveloper(WidgetTester tester) async {
    await tester.tap(find.byTooltip("Menu"));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text("Developer"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Developer"));
    await tester.pumpAndSettle();
  }

  testWidgets('the developer panel is only in the menu when turned on', (tester) async {
    await pumpStory(tester, developer: false);
    await tester.tap(find.byTooltip("Menu"));
    await tester.pumpAndSettle();
    expect(find.text("Developer"), findsNothing);
    expect(find.text("Story variables", skipOffstage: false), findsOneWidget);
  });

  testWidgets('variables can be added and edited', (tester) async {
    final (controller, _) = await pumpStory(tester);
    await openDeveloper(tester);

    await tester.tap(find.text("Add variable"));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, "Name"), "trust");
    await tester.enterText(find.widgetWithText(TextField, "Value"), "12");
    await tester.tap(find.text("Set"));
    await tester.pumpAndSettle();
    expect(controller.dataMap["trust"], 12);

    await tester.tap(find.text("trust"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), "true");
    await tester.tap(find.text("Set"));
    await tester.pumpAndSettle();
    expect(controller.dataMap["trust"], true);
    expect(find.text("true"), findsOneWidget);
  });

  testWidgets('jumps to a label in another conversation, keeping the variables', (tester) async {
    final (controller, _) = await pumpStory(tester);
    await controller.setVariable("NAME", "Rin");
    await openDeveloper(tester);
    await tester.tap(find.text("Jump"));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Day 2"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("#cafe"));
    await tester.pumpAndSettle();
    expect(find.byType(DeveloperSheet), findsNothing);
    expect(controller.current?.getText(), "At the café, Rin");
    expect(controller.conversation?.key, "day2");
  });

  testWidgets('the check tab lists the story issues', (tester) async {
    await pumpStory(tester);
    await openDeveloper(tester);
    await tester.tap(find.text("Check"));
    await tester.pumpAndSettle();
    expect(find.text("Unknown character 'ghost'"), findsOneWidget);
    expect(find.text("Variable 'NAME' is read but never set"), findsOneWidget);
    expect(find.text("cvn_day2.json #1"), findsNWidgets(2));
  });

  testWidgets('a hot reload reads the edited story and stays on the line', (tester) async {
    final (controller, files) = await pumpStory(tester);
    await tester.tapAt(const Offset(200, 300));
    await tester.pumpAndSettle();
    expect(controller.current?.getText(), "Two");

    (files["index"]!["conversations"] as List)[1] = _text("Two, rewritten");
    // Finishes with the next frame, which only the pumps produce.
    final reassembled = tester.binding.reassembleApplication();
    await tester.pumpAndSettle();
    await reassembled;
    expect(controller.current?.getText(), "Two, rewritten");
    expect(find.text("Story reloaded"), findsOneWidget);

    await tester.tapAt(const Offset(200, 300));
    await tester.pumpAndSettle();
    expect(controller.current?.getText(), "Morning");
  });

  test('values typed in the panel', () {
    expect(DeveloperSheet.parseValue(" 3.5 "), 3.5);
    expect(DeveloperSheet.parseValue("false"), false);
    expect(DeveloperSheet.parseValue("'Blue'"), "Blue");
    expect(DeveloperSheet.parseValue("Blue"), "Blue");
    expect(DeveloperSheet.parseValue('"12"'), "12");
  });
}
