import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:cerita_ui/cerita_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: CeritaTheme.dark(),
      home: StorySkinScope(
        skin: const AnimeVnSkin(),
        child: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('dialogue box shows the name plate and the typed line', (tester) async {
    await tester.pumpWidget(_wrap(const DialogueBox('Hello there', speaker: 'Nora', instant: true)));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Nora'), findsOneWidget);
    expect(find.text('Hello there'), findsOneWidget);
  });

  testWidgets('choices stagger in with their text tags and keep locked ones untappable', (tester) async {
    final item = ChoiceItemType.fromJson({
      "type": "CHOICE",
      "text": "Reply?",
      "choices": [
        {"text": "{b}Kind{/b}"},
        {"text": "Secret", "condition": "has_photo"},
      ],
    }).withAvailability((condition) => condition == null);
    final selected = <String>[];
    await tester.pumpWidget(_wrap(ChoiceList(item: item, dark: true, onSelected: (c) => selected.add(c.text))));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    await tester.tap(find.text('Secret'));
    await tester.tap(find.text('Kind'));
    expect(selected, ['{b}Kind{/b}']);
  });

  testWidgets('a long chapter label is cut short and leaves the HUD buttons in place', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final hud = VnHud(
      label: 'The Night Everything Went Quiet On The Other End Of The Line · 23:40',
      autoMode: false,
      skipMode: false,
      onBacklog: () {},
      onAuto: () {},
      onSkip: () {},
      onMenu: () {},
      onHide: () {},
    );
    for (final skin in const [StorySkin(), AnimeVnSkin()]) {
      await tester.pumpWidget(MaterialApp(
        theme: CeritaTheme.dark(),
        home: Scaffold(body: Builder(builder: (context) => skin.vnHud(context, hud))),
      ));
      expect(tester.takeException(), isNull, reason: "${skin.runtimeType} overflows");
    }
  });

  testWidgets('title screen lays out its menu', (tester) async {
    var started = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: CeritaTheme.dark(),
        home: CeritaTitleScreen(
          title: 'Wrong Number',
          art: const ColoredBox(color: Colors.black),
          primary: [TitleMenuEntry(label: 'New game', icon: Icons.play_arrow, onTap: () => started = true)],
          secondary: [TitleMenuEntry(label: 'Gallery', icon: Icons.photo, onTap: () {})],
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('New game'));
    expect(started, isTrue);
    expect(find.text('Gallery'), findsOneWidget);
  });
}
