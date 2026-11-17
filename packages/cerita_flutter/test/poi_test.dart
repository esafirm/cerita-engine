import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

PoiActor _actor(String id, SpritePosition position, [String sprite = "x.png"]) =>
    PoiActor(id: id, sprite: sprite, position: position);

StageItemType _direction(List<Map<String, dynamic>> actions) =>
    StageItemType.fromJson({"type": "STAGE", "actions": actions});

Alignment _alignmentOf(WidgetTester tester, String id) =>
    tester.widget<AnimatedAlign>(find.byKey(ValueKey(id))).alignment as Alignment;

/// The widest the sprite of [id] may be.
double _cap(WidgetTester tester, String id) => tester
    .widget<ConstrainedBox>(find.descendant(of: find.byKey(ValueKey(id)), matching: find.byType(ConstrainedBox)).first)
    .constraints
    .maxWidth;

List<String> _paintOrder(WidgetTester tester) => [
      for (final align in tester.widgetList<AnimatedAlign>(find.byType(AnimatedAlign)))
        if (align.key case ValueKey<String>(:final value)) value,
    ];

void main() {
  testWidgets('a moved character keeps its widget and slides to the new slot', (tester) async {
    await tester.pumpWidget(_wrap(Poi(actors: [_actor("nora", SpritePosition.left)])));
    final element = tester.element(find.byKey(const ValueKey("nora")));
    expect(_alignmentOf(tester, "nora").x, -1.3);

    await tester.pumpWidget(_wrap(Poi(
      actors: [_actor("nora", SpritePosition.right)],
      direction: _direction([{"action": "move", "profile": "nora", "position": "right", "duration_ms": 600}]),
    )));
    expect(tester.element(find.byKey(const ValueKey("nora"))), same(element));
    expect(_alignmentOf(tester, "nora").x, 1.3);
    expect(tester.widget<AnimatedAlign>(find.byKey(const ValueKey("nora"))).duration, const Duration(milliseconds: 600));
  });

  testWidgets('far slots switch to the five slot layout', (tester) async {
    await tester.pumpWidget(_wrap(Poi(actors: [
      _actor("nora", SpritePosition.left),
      _actor("miki", SpritePosition.farRight),
    ])));
    expect(_alignmentOf(tester, "nora").x, -0.75);
    expect(_alignmentOf(tester, "miki").x, 1.5);
  });

  testWidgets('on a portrait stage two characters are capped to stand side by side, in a fixed paint order',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    double cap(String id) => _cap(tester, id);
    List<String> paintOrder() => _paintOrder(tester);

    await tester.pumpWidget(_wrap(Poi(actors: [_actor("nora", SpritePosition.center)])));
    expect(cap("nora"), 400, reason: "a lone character keeps the full width");

    final actors = [_actor("nora", SpritePosition.left), _actor("miki", SpritePosition.right)];
    await tester.pumpWidget(_wrap(Poi(actors: actors, speakerId: "nora")));
    await tester.pumpAndSettle();
    expect(cap("nora"), closeTo(400 * Poi.widthShare(2), 0.01));
    expect(cap("miki"), closeTo(400 * Poi.widthShare(2), 0.01));
    expect(paintOrder(), ["nora", "miki"]);

    await tester.pumpWidget(_wrap(Poi(actors: actors, speakerId: "miki")));
    expect(paintOrder(), ["nora", "miki"], reason: "the speaker doesn't jump to the front");
  });

  testWidgets('on a portrait stage the width cap eases to its new share when a character enters or leaves',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final two = 400 * Poi.widthShare(2);

    await tester.pumpWidget(_wrap(Poi(actors: [_actor("nora", SpritePosition.center)])));
    expect(_cap(tester, "nora"), 400);

    final actors = [_actor("nora", SpritePosition.center), _actor("miki", SpritePosition.right)];
    await tester.pumpWidget(_wrap(Poi(actors: actors)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_cap(tester, "nora"), inExclusiveRange(two, 400), reason: "shrinks over the sprite transition");
    await tester.pumpAndSettle();
    expect(_cap(tester, "nora"), closeTo(two, 0.01));

    await tester.pumpWidget(_wrap(Poi(actors: [_actor("nora", SpritePosition.center)])));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_cap(tester, "nora"), inExclusiveRange(two, 400), reason: "grows back over the sprite transition");
    expect(_cap(tester, "miki"), inExclusiveRange(two, 400), reason: "the leaving one keeps pace");
    await tester.pumpAndSettle();
    expect(_cap(tester, "nora"), 400);
    expect(find.byKey(const ValueKey("miki")), findsNothing);

    await tester.pumpWidget(_wrap(const Poi()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_cap(tester, "nora"), 400, reason: "the last one leaving doesn't change size");
  });

  testWidgets('on a portrait stage three characters spread out and stay on screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Left and right edge of a sprite as wide as its cap.
    (double, double) span(String id) {
      final width = _cap(tester, id);
      final left = (400 - width) * (1 + _alignmentOf(tester, id).x) / 2;
      return (left, left + width);
    }

    // The Last Seen scene: Raka left, Dinda far right, Yusuf center.
    await tester.pumpWidget(_wrap(Poi(actors: [
      _actor("raka", SpritePosition.left),
      _actor("dinda", SpritePosition.farRight),
      _actor("yusuf", SpritePosition.center),
    ])));
    await tester.pumpAndSettle();
    final [raka, yusuf, dinda] = [for (final id in ["raka", "yusuf", "dinda"]) span(id)];
    for (final (left, right) in [raka, yusuf, dinda]) {
      expect(left, greaterThanOrEqualTo(-0.01));
      expect(right, lessThanOrEqualTo(400.01));
    }
    final width = _cap(tester, "raka");
    expect(raka.$2 - yusuf.$1, lessThan(width / 2), reason: "Yusuf covers less than half of Raka");
    expect(yusuf.$2 - dinda.$1, lessThan(width / 2));
    expect(_paintOrder(tester), ["raka", "dinda", "yusuf"]);

    await tester.pumpWidget(_wrap(Poi(actors: [
      _actor("raka", SpritePosition.left),
      _actor("dinda", SpritePosition.farRight),
      _actor("yusuf", SpritePosition.center),
    ], speakerId: "yusuf")));
    expect(_paintOrder(tester), ["raka", "dinda", "yusuf"]);
  });

  testWidgets('a landscape stage keeps the slot spacing with three characters', (tester) async {
    await tester.pumpWidget(_wrap(Poi(actors: [
      _actor("raka", SpritePosition.left),
      _actor("dinda", SpritePosition.farRight),
      _actor("yusuf", SpritePosition.center),
    ])));
    expect(_alignmentOf(tester, "raka").x, -0.75);
    expect(_alignmentOf(tester, "yusuf").x, 0);
    expect(_alignmentOf(tester, "dinda").x, 1.5);
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
