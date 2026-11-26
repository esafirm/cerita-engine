import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('RouteFlowchart handles empty RouteMap without negative height crash', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RouteFlowchart(
            map: RouteMap(const StoryGraph([])),
            meta: GlobalMetaState(),
            onSelect: (_) {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('StoryLanguage.stringsFor resolves regional locale tags to base language', () {
    final language = StoryLanguage();
    expect(language.stringsFor("id-ID").settings, CeritaStrings.id.settings);
    expect(language.stringsFor("en-US").settings, CeritaStrings.en.settings);
  });

  testWidgets('SettingsScreen reset preserves developerTools toggle', (tester) async {
    final storage = InMemoryStoryStorage();
    final prefs = PlayerPrefs(storage);
    await prefs.update(const PlayerSettings(developerTools: true, textMsPerChar: 80));

    await tester.pumpWidget(MaterialApp(home: SettingsScreen(settings: prefs)));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Reset"));
    await tester.pumpAndSettle();

    expect(prefs.value.textMsPerChar, const PlayerSettings().textMsPerChar);
    expect(prefs.value.developerTools, isTrue);
  });

  test('SharedPrefsStoryStorage isolates dotted namespaces', () async {
    SharedPreferences.setMockInitialValues({});
    final parent = SharedPrefsStoryStorage(namespace: "story");
    final child = SharedPrefsStoryStorage(namespace: "story.demo");

    final slot = SaveSlot(
      slotId: 1,
      conversationKey: "index",
      dialogIndex: 0,
      dataMap: const {},
      history: const [],
      updatedAt: DateTime(2026),
    );
    await parent.saveSlot(slot);
    await child.saveSlot(slot.copyWith(slotId: 2));

    expect((await parent.listSlots()).map((s) => s.slotId), [1]);
    expect((await child.listSlots()).map((s) => s.slotId), [2]);

    await parent.clear();
    expect(await parent.listSlots(), isEmpty);
    expect((await child.listSlots()).map((s) => s.slotId), [2]);
  });

  testWidgets('InputPrompt clears text when item changes', (tester) async {
    final first = InputItemType.fromJson({"type": "INPUT", "text": "First?", "variable": "A"});
    final second = InputItemType.fromJson({"type": "INPUT", "text": "Second?", "variable": "B"});

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: InputPrompt(item: first, onSubmit: (_) {}))));
    await tester.enterText(find.byType(TextField), "hello");
    expect(find.text("hello"), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: InputPrompt(item: second, onSubmit: (_) {}))));
    expect(find.text("hello"), findsNothing);
  });
}
