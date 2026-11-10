import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:cerita_flutter/src/scene_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads the shared story state once, like a scene view built from the controller.
class _Scene extends StatefulWidget {
  final String Function() read;

  const _Scene(this.read);

  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> {
  late final String _text = widget.read();

  @override
  Widget build(BuildContext context) => Text(_text);
}

Widget _switcher(String scene, SceneMode mode, Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: SceneSwitcher(scene: scene, mode: mode, child: child),
    );

void main() {
  testWidgets('the outgoing scene keeps its state during the transition', (tester) async {
    var state = "prologue";
    Widget switcher(String scene, SceneMode mode) => _switcher(scene, mode, _Scene(() => state));

    await tester.pumpWidget(switcher("a", SceneMode.vn));
    state = "day 1";
    await tester.pumpWidget(switcher("b", SceneMode.chat));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text("prologue"), findsOneWidget);
    expect(find.text("day 1"), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text("prologue"), findsNothing);
  });

  testWidgets('only the incoming scene takes taps', (tester) async {
    final taps = <String>[];
    Widget scene(String name) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => taps.add(name),
          child: const SizedBox.expand(),
        );

    await tester.pumpWidget(_switcher("a", SceneMode.vn, scene("a")));
    await tester.pumpWidget(_switcher("b", SceneMode.vn, scene("b")));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(const Offset(10, 10));

    expect(taps, ["b"]);
  });
}
