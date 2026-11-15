import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoMarkerSkin extends StorySkin {
  const _NoMarkerSkin();

  @override
  Widget? memoryMarker(BuildContext context, Choice choice, {required bool dark}) => null;
}

class _StarSkin extends StorySkin {
  const _StarSkin();

  @override
  Widget? memoryMarker(BuildContext context, Choice choice, {required bool dark}) => const Icon(Icons.star);
}

Widget _wrap(Widget child, {StorySkin skin = const StorySkin()}) =>
    MaterialApp(home: StorySkinScope(skin: skin, child: Scaffold(body: child)));

final _item = ChoiceItemType.fromJson({
  "type": "CHOICE",
  "text": "Answer",
  "choices": [
    {"text": "Mention the storm", "condition": "meta.ending.end_storm", "memory_marker": true},
    {"text": "Show the receipt", "condition": "has_receipt", "memory_marker": true},
    {"text": "Nothing yet"},
  ],
}).withAvailability((condition) => condition != "has_receipt");

void main() {
  testWidgets('the default skin marks available memory_marker choices only', (tester) async {
    final selected = <String>[];
    await tester.pumpWidget(_wrap(ChoiceList(item: _item, onSelected: (c) => selected.add(c.text))));

    // The locked one shows its lock instead.
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    final storm = find.widgetWithText(InkWell, 'Mention the storm');
    expect(find.descendant(of: storm, matching: find.byIcon(Icons.auto_awesome)), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    await tester.tap(find.text('Mention the storm'));
    expect(selected, ['Mention the storm']);
  });

  testWidgets('skins restyle or hide the marker', (tester) async {
    await tester.pumpWidget(_wrap(ChoiceList(item: _item, onSelected: (_) {}), skin: const _StarSkin()));
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsNothing);

    await tester.pumpWidget(_wrap(ChoiceList(item: _item, onSelected: (_) {}), skin: const _NoMarkerSkin()));
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.byIcon(Icons.auto_awesome), findsNothing);
    expect(find.text('Mention the storm'), findsOneWidget);
  });
}
