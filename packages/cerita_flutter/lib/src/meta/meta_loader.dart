import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../story_setup.dart';

/// Loads the story catalog and the global meta-state for meta-game screens.
class MetaLoader extends StatefulWidget {
  final StorySetup setup;
  final Widget Function(BuildContext context, StoryCatalog catalog, GlobalMetaState meta) builder;

  const MetaLoader({super.key, required this.setup, required this.builder});

  @override
  State<MetaLoader> createState() => _MetaLoaderState();
}

class _MetaLoaderState extends State<MetaLoader> {
  late Future<(StoryCatalog, GlobalMetaState)> _future = _load();

  Future<(StoryCatalog, GlobalMetaState)> _load() async {
    final results = await Future.wait([StoryCatalog.load(widget.setup.loader), widget.setup.storage.loadMeta()]);
    return (results[0] as StoryCatalog, results[1] as GlobalMetaState);
  }

  @override
  void didUpdateWidget(MetaLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setup != widget.setup) _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("${snapshot.error}"));
        final data = snapshot.data;
        if (data == null) return const Center(child: CircularProgressIndicator());
        return widget.builder(context, data.$1, data.$2);
      },
    );
  }
}
