import 'dart:async';
import 'dart:convert';

import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

PoiActor _actor(String id, SpritePosition position, [String sprite = "x.png"]) =>
    PoiActor(id: id, sprite: sprite, position: position);

StageItemType _direction(List<Map<String, dynamic>> actions) =>
    StageItemType.fromJson({"type": "STAGE", "actions": actions});

/// Where the sprite of [id] is drawn: its height, its bottom edge and its center x.
Rect _slot(WidgetTester tester, String id) =>
    tester.getRect(find.descendant(of: find.byKey(ValueKey(id)), matching: find.byType(OverflowBox)));

Alignment _alignmentOf(WidgetTester tester, String id) =>
    tester
            .widget<AnimatedAlign>(find.descendant(of: find.byKey(ValueKey(id)), matching: find.byType(AnimatedAlign)))
            .alignment
        as Alignment;

List<String> _paintOrder(WidgetTester tester) => [
  for (final slot in tester.widgetList<Positioned>(find.byType(Positioned)))
    if (slot.key case ValueKey<String>(:final value)) value,
];

Future<void> _portrait(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('a moved character keeps its widget and slides to the new slot', (tester) async {
    await tester.pumpWidget(_wrap(Poi(actors: [_actor("nora", SpritePosition.left)])));
    final element = tester.element(find.byKey(const ValueKey("nora")));
    final left = _slot(tester, "nora").center.dx;

    await tester.pumpWidget(
      _wrap(
        Poi(
          actors: [_actor("nora", SpritePosition.right)],
          direction: _direction([
            {"action": "move", "profile": "nora", "position": "right", "duration_ms": 600},
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.element(find.byKey(const ValueKey("nora"))), same(element));
    expect(_slot(tester, "nora").center.dx, closeTo(800 - left, 0.01), reason: "the mirrored slot");
    final align = find.descendant(of: find.byKey(const ValueKey("nora")), matching: find.byType(AnimatedAlign));
    expect(tester.widget<AnimatedAlign>(align).duration, const Duration(milliseconds: 600));
  });

  testWidgets('without heights every sprite stands on the bottom edge at one size', (tester) async {
    await _portrait(tester);
    await tester.pumpWidget(
      _wrap(Poi(actors: [_actor("nora", SpritePosition.left), _actor("miki", SpritePosition.right)])),
    );
    await tester.pumpAndSettle();
    for (final id in ["nora", "miki"]) {
      expect(_slot(tester, id).bottom, 800);
      expect(_slot(tester, id).height, closeTo(800 * Poi.heightShare(2, narrow: true), 0.01));
    }
  });

  testWidgets('faces come out in proportion to height, eyes at eye height, and every cut stays below the edge', (
    tester,
  ) async {
    await _portrait(tester);
    // Nora is 180: eyes to chin is 12, so her sprite, with the face over a tenth of it, is 120 long, from 180 down
    // to 60. Miki is 150: 10, drawn with a bigger face, so 100 long, from 160 down to 60.
    await tester.pumpWidget(
      _wrap(
        const Poi(
          actors: [
            PoiActor(
              id: "nora",
              sprite: "x.png",
              position: SpritePosition.left,
              height: 180,
              face: SpriteFace(eyes: 0.1, chin: 0.2),
            ),
            PoiActor(
              id: "miki",
              sprite: "x.png",
              position: SpritePosition.right,
              height: 150,
              face: SpriteFace(eyes: 0.2, chin: 0.3),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final nora = _slot(tester, "nora");
    final miki = _slot(tester, "miki");
    final scale = 800 * Poi.heightShare(2, narrow: true) / (180 - 60);
    expect(nora.height, closeTo(120 * scale, 0.01));
    expect(miki.height, closeTo(100 * scale, 0.01));
    expect(nora.bottom, closeTo(800, 0.01), reason: "the highest cut sits on the edge");
    expect(miki.bottom, closeTo(800, 0.01));
    expect(800 - nora.top, closeTo(800 * Poi.heightShare(2, narrow: true), 0.01), reason: "the highest head");
    // Eyes to chin on screen: 12 and 10, as tall as they are.
    expect(nora.height * 0.1 / (miki.height * 0.1), closeTo(180 / 150, 0.001));
    // The eye lines are 168 and 140 above the floor.
    final noraEyes = nora.top + nora.height * 0.1;
    final mikiEyes = miki.top + miki.height * 0.2;
    expect(mikiEyes - noraEyes, closeTo((168 - 140) * scale, 0.01));
  });

  testWidgets('a head-to-toe sprite stands next to a cut one with its feet off the stage', (tester) async {
    await _portrait(tester);
    await tester.pumpWidget(
      _wrap(
        const Poi(
          actors: [
            PoiActor(id: "nora", sprite: "x.png", position: SpritePosition.left, height: 180),
            PoiActor(
              id: "miki",
              sprite: "x.png",
              position: SpritePosition.right,
              height: 150,
              face: SpriteFace(eyes: 0.2, chin: 0.3),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scale = 800 * Poi.heightShare(2, narrow: true) / (180 - 60);
    expect(_slot(tester, "nora").height, closeTo(180 * scale, 0.01));
    expect(_slot(tester, "nora").bottom, closeTo(800 + 60 * scale, 0.01));
  });

  testWidgets('the story stage gives each character its height and face', (tester) async {
    mockAudioChannels();
    final setup = StorySetup(
      config: const LoaderConfig(),
      loader: FakeEngineLoader(
        {
          "index": {
            "conversation_id": "cvn",
            "scene": {"mode": "VN"},
            "conversations": [
              {
                "type": "STAGE",
                "actions": [
                  {"action": "show", "profile": "nora:0", "position": "left"},
                ],
              },
              {"type": "TEXT", "text": "Hi", "profile": "nora:0"},
            ],
          },
        },
        profiles: [
          {
            "id": "nora",
            "name": "Nora",
            "sprites": ["nora.png"],
            "height": 170,
            "face": {"eyes": 0.1, "chin": 0.2},
          },
        ],
      ),
      storage: InMemoryStoryStorage(),
      audio: SilentAudio.new,
    );
    await tester.pumpWidget(MaterialApp(home: StoryScreen(setup: setup)));
    await tester.pumpAndSettle();
    final actor = tester.widget<Poi>(find.byType(Poi)).actors.single;
    expect(actor.height, 170);
    expect(actor.face?.eyes, 0.1);
    expect(actor.face?.chin, 0.2);
  });

  testWidgets('with the whole cast measured, a character keeps their size whoever is on stage', (tester) async {
    await _portrait(tester);
    const cast = PoiCast(tallest: 180);
    const miki = PoiActor(id: "miki", sprite: "x.png", position: SpritePosition.center, height: 150);
    await tester.pumpWidget(_wrap(const Poi(actors: [miki], cast: cast)));
    await tester.pumpAndSettle();
    expect(_slot(tester, "miki").height, closeTo(800 * Poi.heightShare(1, narrow: true) * 150 / 180, 0.01));
  });

  testWidgets('on a portrait stage a crowd barely shrinks, spreads evenly and keeps a fixed paint order', (
    tester,
  ) async {
    await _portrait(tester);
    await tester.pumpWidget(_wrap(Poi(actors: [_actor("nora", SpritePosition.center)])));
    await tester.pumpAndSettle();
    expect(_slot(tester, "nora").center.dx, 200, reason: "a lone character stands in the middle");
    final alone = _slot(tester, "nora").height;

    // The Last Seen scene: Raka left, Dinda far right, Yusuf center.
    final actors = [
      _actor("raka", SpritePosition.left),
      _actor("dinda", SpritePosition.farRight),
      _actor("yusuf", SpritePosition.center),
    ];
    await tester.pumpWidget(_wrap(Poi(actors: actors, speakerId: "raka")));
    await tester.pumpAndSettle();
    expect(_slot(tester, "raka").height, greaterThan(alone * 0.75), reason: "not shrunk into dolls");
    final gap = 400 * Poi.spacing(3);
    expect(_slot(tester, "raka").center.dx, closeTo(200 - gap, 0.01));
    expect(_slot(tester, "yusuf").center.dx, closeTo(200, 0.01));
    expect(_slot(tester, "dinda").center.dx, closeTo(200 + gap, 0.01));
    expect(_paintOrder(tester), ["raka", "dinda", "yusuf"]);

    await tester.pumpWidget(_wrap(Poi(actors: actors, speakerId: "yusuf")));
    expect(_paintOrder(tester), ["raka", "dinda", "yusuf"], reason: "the speaker doesn't jump to the front");
  });

  testWidgets('on a portrait stage the size eases when a character enters or leaves', (tester) async {
    await _portrait(tester);
    final one = 800 * Poi.heightShare(1, narrow: true);
    final three = 800 * Poi.heightShare(3, narrow: true);
    await tester.pumpWidget(_wrap(Poi(actors: [_actor("nora", SpritePosition.center)])));
    await tester.pumpAndSettle();
    expect(_slot(tester, "nora").height, closeTo(one, 0.01));

    final actors = [
      _actor("nora", SpritePosition.center),
      _actor("miki", SpritePosition.right),
      _actor("rin", SpritePosition.left),
    ];
    await tester.pumpWidget(_wrap(Poi(actors: actors)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_slot(tester, "nora").height, inExclusiveRange(three, one), reason: "shrinks over the sprite transition");
    await tester.pumpAndSettle();
    expect(_slot(tester, "nora").height, closeTo(three, 0.01));

    await tester.pumpWidget(_wrap(const Poi()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_slot(tester, "nora").height, closeTo(three, 0.01), reason: "the last ones leaving don't change size");
  });

  testWidgets('a landscape stage keeps the slots apart and every slot at least half on screen', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Poi(
          actors: [
            _actor("raka", SpritePosition.farLeft),
            _actor("bima", SpritePosition.left),
            _actor("yusuf", SpritePosition.center),
            _actor("hendra", SpritePosition.right),
            _actor("dinda", SpritePosition.farRight),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final xs = [
      for (final id in ["raka", "bima", "yusuf", "hendra", "dinda"]) _slot(tester, id).center.dx,
    ];
    expect(xs, orderedEquals([...xs]..sort()));
    expect(xs.first, greaterThan(0));
    expect(xs.last, lessThan(800));
    expect(xs[2], 400);
    expect(_alignmentOf(tester, "yusuf").x, 0);
  });

  testWidgets('a new expression waits for its image, so the old one never fades out over an empty slot', (
    tester,
  ) async {
    final bundle = _SlowBundle();
    Widget stage(String sprite) => DefaultAssetBundle(
      bundle: bundle,
      child: _wrap(Poi(actors: [_actor("nora", SpritePosition.center, sprite)], speakerId: "nora")),
    );
    List<String> shown() => [
      for (final image in tester.widgetList<Image>(find.byType(Image)))
        if (image.image case AssetImage(:final assetName)) assetName,
    ];

    await tester.pumpWidget(stage("a.png"));
    await tester.runAsync(() async => bundle.release("a.png"));
    await tester.pumpAndSettle();
    expect(shown(), ["a.png"]);

    await tester.pumpWidget(stage("b.png"));
    await tester.pump(const Duration(seconds: 1));
    expect(shown(), ["a.png"], reason: "b.png isn't loaded yet");

    await tester.runAsync(() async {
      bundle.release("b.png");
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(shown(), ["b.png"]);
  });

  testWidgets('an expression change disposes what its cross-fade creates', (tester) async {
    var live = 0;
    void track(ObjectEvent event) {
      if (event.object is! CurvedAnimation) return;
      if (event is ObjectCreated) live++;
      if (event is ObjectDisposed) live--;
    }

    FlutterMemoryAllocations.instance.addListener(track);
    addTearDown(() => FlutterMemoryAllocations.instance.removeListener(track));

    await tester.pumpWidget(_wrap(Poi(actors: [_actor("nora", SpritePosition.center, "a.png")], speakerId: "nora")));
    await tester.pumpWidget(_wrap(Poi(actors: [_actor("nora", SpritePosition.center, "b.png")], speakerId: "nora")));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(_wrap(Poi(actors: [_actor("nora", SpritePosition.center, "b.png")], speakerId: "miki")));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    expect(live, 0);
  });

  testWidgets('a hidden character plays its exit transition, or leaves at once when instant', (tester) async {
    await tester.pumpWidget(_wrap(Poi(actors: [_actor("nora", SpritePosition.center)])));
    await tester.pumpWidget(_wrap(Poi(
      direction: _direction([{"action": "hide", "profile": "nora", "transition": "slide_left", "duration_ms": 800}]),
    )));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey("nora")), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey("nora")), findsNothing);

    await tester.pumpWidget(_wrap(Poi(actors: [_actor("miki", SpritePosition.center)])));
    await tester.pumpWidget(_wrap(const Poi(instant: true)));
    expect(find.byKey(const ValueKey("miki")), findsNothing);
  });

  testWidgets('weather, shake, flash and zoom render', (tester) async {
    await tester.pumpWidget(_wrap(const Poi()));
    await tester.pumpWidget(_wrap(Poi(
      weather: "rain",
      zoom: 1.3,
      zoomFocus: SpritePosition.left,
      direction: _direction([
        {"action": "shake", "intensity": 8},
        {"action": "flash", "color": "#FF0000"},
        {"action": "weather", "name": "rain"},
        {"action": "zoom", "scale": 1.3, "focus": "left"},
      ]),
    )));
    expect(find.byType(WeatherLayer), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byWidgetPredicate((w) => w is ColoredBox && w.color.r == 1 && w.color.a > 0), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });
}

/// Serves a 1×1 PNG for any asset, each only once [release] lets it through.
class _SlowBundle extends CachingAssetBundle {
  static final _pixel = base64Decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==",
  );
  final _waiting = <String, Completer<void>>{};

  void release(String key) => (_waiting[key] ??= Completer()).complete();

  @override
  Future<ByteData> load(String key) async {
    if (key == "AssetManifest.bin") return const StandardMessageCodec().encodeMessage(<String, Object?>{})!;
    await (_waiting[key] ??= Completer()).future;
    return ByteData.sublistView(_pixel);
  }
}
