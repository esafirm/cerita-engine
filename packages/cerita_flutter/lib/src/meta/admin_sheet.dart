import 'dart:async';

import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../common/story_sheet.dart';
import '../story_setup.dart';

/// Admin tools for testers, in any build: unlock everything the story has, and turn the in-game developer panel
/// on (authoring tools §5). Opened through an [AdminGate], never from a visible menu entry.
class AdminSheet extends StatefulWidget {
  final StorySetup setup;

  const AdminSheet({super.key, required this.setup});

  static Future<void> show(BuildContext context, StorySetup setup) => StorySheet.show(
        context,
        title: "Admin",
        icon: Icons.admin_panel_settings_outlined,
        builder: (_) => AdminSheet(setup: setup),
      );

  @override
  State<AdminSheet> createState() => _AdminSheetState();
}

class _AdminSheetState extends State<AdminSheet> {
  bool _unlocking = false;
  String? _result;

  Future<void> _unlockAll() async {
    setState(() => _unlocking = true);
    final storage = widget.setup.storage;
    String result;
    try {
      final meta = await storage.loadMeta();
      final report = await StoryUnlocker(widget.setup.loader).unlockAll(meta);
      await storage.saveMeta(meta);
      result = "Unlocked ${report.chapters} chapters, ${report.media} pictures and clips, ${report.endings} endings "
          "and ${report.music} tracks.";
      if (report.unplayedChapters.isNotEmpty) {
        result += " No test run reached ${report.unplayedChapters.join(", ")}, so it starts with no variables.";
      }
    } catch (error) {
      result = "Couldn't unlock: $error";
    }
    if (!mounted) return;
    setState(() {
      _unlocking = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = widget.setup.settings;
    return ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          leading: const Icon(Icons.lock_open_outlined),
          title: const Text("Unlock everything"),
          subtitle: Text(_result ?? "Every chapter, picture, ending and music track. Chapters start with the "
              "variables of a test run that reached them."),
          trailing: _unlocking ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator()) : null,
          enabled: !_unlocking,
          onTap: _unlockAll,
        ),
        ValueListenableBuilder(
          valueListenable: prefs,
          builder: (context, settings, _) => SwitchListTile(
            secondary: const Icon(Icons.build_outlined),
            title: const Text("Developer tools"),
            subtitle: const Text("Adds Developer to the in-game menu: variables, jump anywhere, story check."),
            value: settings.developerTools,
            onChanged: (on) => prefs.update(settings.copyWith(developerTools: on)),
          ),
        ),
      ],
    );
  }
}

/// Opens the [AdminSheet] after [taps] quick taps on [child], like the build number tap that unlocks Android's
/// developer options. Each tap must come within [window] of the last one.
class AdminGate extends StatefulWidget {
  final StorySetup setup;
  final Widget child;
  final int taps;
  final Duration window;

  const AdminGate({
    super.key,
    required this.setup,
    required this.child,
    this.taps = 7,
    this.window = const Duration(milliseconds: 600),
  });

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  int _count = 0;

  /// Starts the count over when no tap follows within the window.
  Timer? _reset;

  void _tap() {
    _reset?.cancel();
    _count++;
    if (_count >= widget.taps) {
      _count = 0;
      AdminSheet.show(context, widget.setup);
      return;
    }
    _reset = Timer(widget.window, () => _count = 0);
  }

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      GestureDetector(behavior: HitTestBehavior.opaque, onTap: _tap, child: widget.child);
}
