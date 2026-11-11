import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../story_controller.dart';
import '../story_setup.dart';

/// Developer panel of a running story: edit variables, jump to any conversation or label, check the
/// story with [StoryLinter] and reload the story files. Shown when [StorySetup.developer] is on.
class DeveloperSheet extends StatelessWidget {
  final StoryController controller;
  final StorySetup setup;

  const DeveloperSheet({super.key, required this.controller, required this.setup});

  static Future<void> show(BuildContext context, StoryController controller, StorySetup setup) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.85,
          child: DeveloperSheet(controller: controller, setup: setup),
        ),
      );

  /// `true` / `false`, a number, or text (quotes around it are dropped).
  static dynamic parseValue(String raw) {
    final text = raw.trim();
    if (text == "true") return true;
    if (text == "false") return false;
    final number = num.tryParse(text);
    if (number != null) return number;
    final quoted = RegExp(r'''^(['"])(.*)\1$''').firstMatch(text);
    return quoted == null ? text : quoted.group(2);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 16),
              Expanded(child: Text("Developer", style: Theme.of(context).textTheme.titleLarge)),
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Reload story"),
                onPressed: () {
                  Navigator.of(context).pop();
                  controller.reloadStory();
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          const TabBar(tabs: [Tab(text: "Variables"), Tab(text: "Jump"), Tab(text: "Check")]),
          Expanded(
            child: TabBarView(
              children: [
                _Variables(controller: controller),
                _Jump(controller: controller, setup: setup),
                _Check(setup: setup),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Variables extends StatelessWidget {
  final StoryController controller;

  const _Variables({required this.controller});

  Future<void> _edit(BuildContext context, {String? name, dynamic value}) async {
    final nameField = TextEditingController(text: name);
    final valueField = TextEditingController(text: value is String ? '"$value"' : value?.toString() ?? "");
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name ?? "New variable"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (name == null)
              TextField(controller: nameField, autofocus: true, decoration: const InputDecoration(labelText: "Name")),
            TextField(
              controller: valueField,
              autofocus: name != null,
              decoration: const InputDecoration(labelText: "Value", helperText: "true, false, a number, or text"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Set")),
        ],
      ),
    );
    final variable = nameField.text.trim();
    if (saved == true && variable.isNotEmpty) {
      await controller.setVariable(variable, DeveloperSheet.parseValue(valueField.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final variables = {
          ...controller.dataMap,
          for (final MapEntry(:key, :value) in controller.engine.meta.persistent.entries) "persistent.$key": value,
        };
        final names = variables.keys.toList()..sort();
        return ListView(
          children: [
            for (final name in names)
              ListTile(
                dense: true,
                title: Text(name, style: const TextStyle(fontFamily: "monospace")),
                trailing: Text(variables[name] is String ? '"${variables[name]}"' : "${variables[name]}"),
                onTap: () => _edit(context, name: name, value: variables[name]),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text("Add variable"),
              onTap: () => _edit(context),
            ),
          ],
        );
      },
    );
  }
}

class _Jump extends StatefulWidget {
  final StoryController controller;
  final StorySetup setup;

  const _Jump({required this.controller, required this.setup});

  @override
  State<_Jump> createState() => _JumpState();
}

class _JumpState extends State<_Jump> {
  late final Future<StoryCatalog> _catalog = StoryCatalog.load(widget.setup.loader);

  void _jump(String target) {
    Navigator.of(context).pop();
    widget.controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _catalog,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("${snapshot.error}"));
        final conversations = snapshot.data?.conversations;
        if (conversations == null) return const Center(child: CircularProgressIndicator());
        final current = widget.controller.conversation?.key;
        return ListView(
          children: [
            for (final conversation in conversations)
              ExpansionTile(
                initiallyExpanded: conversation.key == current,
                title: Text([conversation.chapter, conversation.title].whereType<String>().join(" · ").ifEmpty(conversation.key)),
                subtitle: Text(conversation.key, style: const TextStyle(fontFamily: "monospace")),
                children: [
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.play_arrow_outlined),
                    title: const Text("From the start"),
                    onTap: () => _jump(conversation.key),
                  ),
                  for (final (index, item) in conversation.conversations.indexed)
                    if (item.id case final id?)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.label_outline),
                        title: Text("#$id", style: const TextStyle(fontFamily: "monospace")),
                        subtitle: Text("#$index ${item.getType()}${item.getText() == null ? "" : ": ${TextMarkup.plain(item.getText()!)}"}",
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => _jump("${conversation.key}#$id"),
                      ),
                ],
              ),
          ],
        );
      },
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class _Check extends StatefulWidget {
  final StorySetup setup;

  const _Check({required this.setup});

  @override
  State<_Check> createState() => _CheckState();
}

class _CheckState extends State<_Check> {
  late Future<List<LintIssue>> _issues = _lint();

  Future<List<LintIssue>> _lint() async {
    // Missing files are found too when the loader knows which ones exist.
    final loader = widget.setup.loader;
    final assetExists = await loader.assetChecker().catchError((_) => null);
    return StoryLinter(loader, config: widget.setup.config, assetExists: assetExists).lint();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder(
      future: _issues,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("${snapshot.error}"));
        final issues = snapshot.data;
        if (issues == null) return const Center(child: CircularProgressIndicator());
        return RefreshIndicator(
          onRefresh: () async {
            widget.setup.loader.clearCache();
            setState(() => _issues = _lint());
            await _issues;
          },
          child: ListView(
            children: [
              if (issues.isEmpty)
                const ListTile(leading: Icon(Icons.check_circle_outline), title: Text("No issues found")),
              for (final issue in issues)
                ListTile(
                  dense: true,
                  leading: Icon(
                    issue.isError ? Icons.error_outline : Icons.warning_amber_outlined,
                    color: issue.isError ? scheme.error : scheme.tertiary,
                  ),
                  title: Text(issue.message),
                  subtitle: Text(
                    [issue.file, if (issue.itemIndex != null) "#${issue.itemIndex}"].join(" "),
                    style: const TextStyle(fontFamily: "monospace"),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
