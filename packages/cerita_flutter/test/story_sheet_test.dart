import 'dart:convert';

import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves a 1×1 PNG for every asset, so a picture has something to load.
class _PixelBundle extends CachingAssetBundle {
  static final _pixel = base64Decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==",
  );

  @override
  Future<ByteData> load(String key) async => key == "AssetManifest.bin"
      ? const StandardMessageCodec().encodeMessage(<String, Object?>{})!
      : ByteData.sublistView(_pixel);
}

void main() {
  const screen = Size(400, 800);

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => DefaultAssetBundle(bundle: _PixelBundle(), child: child!),
      home: const Scaffold(body: SizedBox.expand()),
    ));
    return tester.element(find.byType(Scaffold));
  }

  /// The sheet's height: the skin's panel, from the top of its handle to the bottom of the screen.
  double sheetHeight(WidgetTester tester) => tester.getSize(find.byType(BottomSheet)).height;

  testWidgets('a sheet with one line in it is still a panel, not a strip', (tester) async {
    final context = await pumpHost(tester);
    StorySheet.show<void>(context, title: "Backlog", builder: (_) => const Text("One line"));
    await tester.pumpAndSettle();

    expect(sheetHeight(tester), moreOrLessEquals(screen.height * StorySheet.minHeightFactor));
    // The body sits under the header, at the top of the panel.
    expect(tester.getTopLeft(find.text("One line")).dy, lessThan(screen.height * 0.75));
  });

  testWidgets('a long sheet stops short of the top and scrolls', (tester) async {
    final context = await pumpHost(tester);
    StorySheet.show<void>(
      context,
      title: "Backlog",
      builder: (_) => ListView(shrinkWrap: true, children: [for (var i = 0; i < 80; i++) Text("Line $i")]),
    );
    await tester.pumpAndSettle();

    expect(sheetHeight(tester), moreOrLessEquals(screen.height * StorySheet.maxHeightFactor));
  });

  testWidgets('a picture opens in a full-screen sheet with its caption, and closes like any sheet', (tester) async {
    final context = await pumpHost(tester);
    ImageViewerPage.open(context, "photo.png", caption: "The unsent message");
    await tester.pumpAndSettle();

    expect(sheetHeight(tester), screen.height);
    expect(find.text("Photo"), findsOneWidget);
    expect(find.text("The unsent message"), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerPage), findsNothing);
  });
}
