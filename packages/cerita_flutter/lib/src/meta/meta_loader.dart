import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../story_setup.dart';

/// Loads the story catalog and the global meta-state for meta-game screens.
class MetaLoader extends StatelessWidget {
  final StorySetup setup;
  final Widget Function(BuildContext context, StoryCatalog catalog, GlobalMetaState meta) builder;

  const MetaLoader({super.key, required this.setup, required this.builder});

  Future<(StoryCatalog, GlobalMetaState)> _load() async =>
      (await StoryCatalog.load(setup.loader), await setup.storage.loadMeta());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("${snapshot.error}"));
        final data = snapshot.data;
        if (data == null) return const Center(child: CircularProgressIndicator());
        return builder(context, data.$1, data.$2);
      },
    );
  }
}
