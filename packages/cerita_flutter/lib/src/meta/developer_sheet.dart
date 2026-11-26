import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../common/story_sheet.dart';
import '../l10n/story_language.dart';
import '../story_controller.dart';
import '../story_setup.dart';

/// Developer panel of a running story: edit variables, jump to any conversation or label, check the
/// story with [StoryLinter] and reload the story files. Shown when [StorySetup.developer] is on.
class DeveloperSheet extends StatelessWidget {
  final StoryController controller;
  final StorySetup setup;

  const DeveloperSheet({super.key, required this.controller, required this.setup});

  static Future<void> show(BuildContext context, StoryController controller, StorySetup setup) => StorySheet.show(
    context,
    title: StoryLanguage.of(context).strings.developer,
    icon: Icons.build_outlined,
    expand: true,
    builder: (_) => DeveloperSheet(controller: controller, setup: setup),
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
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Reload story"),
                onPressed: () {
                  Navigator.of(context).pop();
                  controller.reloadStory();
                },
              ),
            ),
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

class _VariableDialog extends StatefulWidget {
  final String? name;
  final dynamic value;

  const _VariableDialog({this.name, this.value});

  @override
  State<_VariableDialog> createState() => _VariableDialogState();
}

class _VariableDialogState extends State<_VariableDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.name);
  late final TextEditingController _value =
      TextEditingController(text: widget.value is String ? '"${widget.value}"' : widget.value?.toString() ?? "");

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.name ?? "New variable"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.name == null)
            TextField(controller: _name, autofocus: true, decoration: const InputDecoration(labelText: "Name")),
          TextField(
            controller: _value,
            autofocus: widget.name != null,
            decoration: const InputDecoration(labelText: "Value", helperText: "true, false, a number, or text"),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((_name.text.trim(), _value.text)),
          child: const Text("Set"),
        ),
      ],
    );
  }
}

class _Variables extends StatelessWidget {
  final StoryController controller;

  const _Variables({required this.controller});

  Future<void> _edit(BuildContext context, {String? name, dynamic value}) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _VariableDialog(name: name, value: value),
    );
    if (result != null && result.$1.isNotEmpty) {
      await controller.setVariable(result.$1, DeveloperSheet.parseValue(result.$2));
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
        // Remembered facts are read-only: only the meta_set effect remembers one, and only Reset progress forgets it.
        final facts = [
          for (final fact in controller.engine.meta.rememberedFacts) "${StoryState.flagPrefix}$fact",
        ]..sort();
        return ListView(
          children: [
            for (final name in names)
              ListTile(
                dense: true,
                title: Text(name, style: const TextStyle(fontFamily: "monospace")),
                trailing: Text(variables[name] is String ? '"${variables[name]}"' : "${variables[name]}"),
                onTap: () => _edit(context, name: name, value: variables[name]),
              ),
            for (final fact in facts)
              ListTile(
                dense: true,
                title: Text(fact, style: const TextStyle(fontFamily: "monospace")),
                subtitle: const Text("Remembered across playthroughs, read-only"),
                trailing: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(Icons.lock_outline, size: 16), SizedBox(width: 4), Text("true")],
                ),
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
                    [
                      issue.file,
                      if (issue.itemIndex != null) "#${issue.itemIndex}",
                      if (issue.path.isNotEmpty) issue.part,
                    ].join(" "),
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
