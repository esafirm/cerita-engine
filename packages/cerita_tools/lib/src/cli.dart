import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'assets.dart';
import 'compiler.dart';
import 'diagnostics.dart';
import 'linter.dart';
import 'project.dart';
import 'stats.dart';
import 'tts_manifest.dart';

/// Exit codes: success, problems found, and bad usage (sysexits `EX_USAGE`).
const exitOk = 0;
const exitProblems = 1;
const exitUsage = 64;

/// The `cerita_tools` command line (spec §3). Output goes to [out] and [err], so tests can capture it.
class CeritaCli {
  final StringSink out;
  final StringSink err;

  CeritaCli(this.out, this.err);

  Future<int> run(List<String> args) async {
    final runner = CommandRunner<int>("cerita_tools", "Compile, check and measure .cerita story scripts.")
      ..addCommand(_CompileCommand(this))
      ..addCommand(_LintCommand(this))
      ..addCommand(_StatsCommand(this))
      ..addCommand(_TtsManifestCommand(this))
      ..addCommand(_AssetsCommand(this));
    try {
      return await runner.run(args) ?? exitOk;
    } on UsageException catch (e) {
      err.writeln(e);
      return exitUsage;
    }
  }
}

abstract class _StoryCommand extends Command<int> {
  final CeritaCli cli;

  _StoryCommand(this.cli);

  StringSink get out => cli.out;

  StringSink get err => cli.err;

  ArgResults get args => argResults!;

  String storyDir() {
    final rest = args.rest;
    if (rest.isEmpty) usageException("Missing the story folder");
    return rest.first;
  }

  StoryProject load(String root, {String? assets}) => StoryProject.load(root, assetsOverride: assets);

  String display(String root, String file) => p.normalize(p.join(root, file));

  /// Prints [diagnostics] and a summary. Returns whether there were errors.
  bool report(String root, Diagnostics diagnostics, {bool summary = true}) {
    for (final diagnostic in diagnostics.sorted()) {
      err.writeln(diagnostic.format((file) => display(root, file)));
    }
    if (summary) {
      final errors = diagnostics.count(Severity.error), warnings = diagnostics.count(Severity.warning);
      final total = errors + warnings;
      err.writeln(total == 0
          ? "No problems"
          : "$total ${total == 1 ? "problem" : "problems"} "
              "($errors ${errors == 1 ? "error" : "errors"}, $warnings ${warnings == 1 ? "warning" : "warnings"})");
    }
    return diagnostics.hasErrors;
  }
}

class _CompileCommand extends _StoryCommand {
  @override
  final name = "compile";
  @override
  final description = "Compile a story folder into the engine's JSON files.";
  @override
  String get invocation => "cerita_tools compile <story> [out]";

  _CompileCommand(super.cli) {
    argParser.addFlag("check", negatable: false, help: "Fail if the files in [out] don't match the scripts.");
  }

  @override
  int run() {
    final root = storyDir();
    final project = load(root);
    final outDir = args.rest.length > 1
        ? args.rest[1]
        : (project.config.out == null ? null : p.join(root, project.config.out));
    if (outDir == null) usageException("Missing the output folder: pass [out] or set 'out' in cerita.yaml");

    final result = compileStory(project);
    if (!result.ok) {
      report(root, result.diagnostics);
      return exitProblems;
    }
    final dir = Directory(outDir);
    final stale = dir.existsSync()
        ? (dir
            .listSync()
            .whereType<File>()
            .map((file) => p.basename(file.path))
            .where((name) => name.startsWith("cvn_") && name.endsWith(".json") && !result.files.containsKey(name))
            .toList()
          ..sort())
        : <String>[];

    if (args.flag("check")) {
      final problems = <String>[
        for (final MapEntry(key: name, value: json) in result.files.entries)
          if (!File(p.join(outDir, name)).existsSync())
            "${p.join(outDir, name)} is missing"
          else if (File(p.join(outDir, name)).readAsStringSync() != json)
            "${p.join(outDir, name)} doesn't match the scripts",
        for (final name in stale) "${p.join(outDir, name)} has no conversation in the scripts",
      ];
      for (final problem in problems) {
        err.writeln("error: $problem");
      }
      if (problems.isNotEmpty) {
        err.writeln("Run `dart run cerita_tools compile $root $outDir` and commit the result");
        return exitProblems;
      }
      out.writeln("${result.files.length} files match the scripts");
      return exitOk;
    }

    dir.createSync(recursive: true);
    var written = 0;
    for (final MapEntry(key: name, value: json) in result.files.entries) {
      final file = File(p.join(outDir, name));
      if (file.existsSync() && file.readAsStringSync() == json) continue;
      file.writeAsStringSync(json);
      written++;
    }
    for (final name in stale) {
      err.writeln("warning: ${p.join(outDir, name)} has no conversation in the scripts. Delete it if it's no longer used");
    }
    out.writeln("Compiled ${result.files.length} files to $outDir ($written changed)");
    return exitOk;
  }
}

class _LintCommand extends _StoryCommand {
  @override
  final name = "lint";
  @override
  final description = "Check a story for broken links, unknown names, missing assets and translations.";
  @override
  String get invocation => "cerita_tools lint <story>";

  _LintCommand(super.cli) {
    argParser
      ..addFlag("release", negatable: false, help: "Treat missing translations and skipped asset checks as errors.")
      ..addOption("assets", help: "Asset folder with bg/, sprites/, media/ and music/. Overrides cerita.yaml.");
  }

  @override
  int run() {
    final root = storyDir();
    final project = load(root, assets: args.option("assets"));
    final diagnostics = lintStory(project, release: args.flag("release"));
    return report(root, diagnostics) ? exitProblems : exitOk;
  }
}

class _StatsCommand extends _StoryCommand {
  @override
  final name = "stats";
  @override
  final description = "Print words and estimated playtime per chapter, conversation and ending.";
  @override
  String get invocation => "cerita_tools stats <story>";

  _StatsCommand(super.cli) {
    argParser
      ..addOption("locale", help: "Locale to count words in. Default: the source locale.")
      ..addOption("wpm", help: "Reading speed in words per minute. Default: from cerita.yaml, else 200.")
      ..addFlag("json", negatable: false, help: "Print JSON.");
  }

  @override
  int run() {
    final root = storyDir();
    final project = load(root);
    if (project.diagnostics.hasErrors) {
      report(root, project.diagnostics);
      return exitProblems;
    }
    final locale = args.option("locale");
    if (locale != null && !project.config.locales.contains(locale)) {
      usageException("Unknown locale '$locale'. The story's locales are ${project.config.locales.join(", ")}");
    }
    final rawWpm = args.option("wpm");
    final wpm = rawWpm == null ? null : num.tryParse(rawWpm);
    if (rawWpm != null && (wpm == null || wpm <= 0)) usageException("--wpm must be a positive number");
    final stats = storyStats(project, locale: locale, wpm: wpm);
    out.write(args.flag("json") ? encodeJson(stats.toJson()) : stats.format());
    return exitOk;
  }
}

class _TtsManifestCommand extends _StoryCommand {
  @override
  final name = "tts-manifest";
  @override
  final description = "Write every voiced line and voice note as JSON for the voice pipeline.";
  @override
  String get invocation => "cerita_tools tts-manifest <story>";

  _TtsManifestCommand(super.cli) {
    argParser.addOption("out", help: "File to write. Default: stdout.");
  }

  @override
  int run() {
    final root = storyDir();
    final project = load(root);
    if (project.diagnostics.hasErrors) {
      report(root, project.diagnostics);
      return exitProblems;
    }
    final warnings = Diagnostics();
    final json = encodeJson(buildTtsManifest(project, warnings));
    report(root, warnings, summary: false);
    final target = args.option("out");
    if (target == null) {
      out.write(json);
    } else {
      File(target).writeAsStringSync(json);
      final count = (jsonDecode(json)["lines"] as List).length;
      err.writeln("Wrote $count lines to $target");
    }
    return exitOk;
  }
}

class _AssetsCommand extends _StoryCommand {
  @override
  final name = "assets";
  @override
  final description = "List the files the story references that don't exist yet, by kind.";
  @override
  String get invocation => "cerita_tools assets <story>";

  _AssetsCommand(super.cli) {
    argParser
      ..addOption("assets", help: "Asset folder with bg/, sprites/, media/ and music/. Overrides cerita.yaml.")
      ..addFlag("json", negatable: false, help: "Print {kind: [path, ...]} as JSON.");
  }

  @override
  int run() {
    final root = storyDir();
    final project = load(root, assets: args.option("assets"));
    if (project.diagnostics.hasErrors) {
      report(root, project.diagnostics);
      return exitProblems;
    }
    final missing = missingAssets(project);
    if (missing == null) {
      err.writeln("error: ${project.assetsError ?? "No asset folder: set 'assets' in cerita.yaml or pass --assets"}");
      return exitProblems;
    }
    final byKind = {
      for (final kind in assetKinds)
        if (missing.any((ref) => ref.kind == kind)) kind: missing.where((ref) => ref.kind == kind).toList(),
    };
    if (args.flag("json")) {
      out.write(encodeJson({
        for (final MapEntry(key: kind, value: refs) in byKind.entries) kind: [for (final ref in refs) ref.path],
      }));
      return exitOk;
    }
    if (byKind.isEmpty) {
      out.writeln("Nothing missing");
      return exitOk;
    }
    for (final MapEntry(key: kind, value: refs) in byKind.entries) {
      out.writeln("$kind (${refs.length})");
      for (final ref in refs) {
        out.writeln("  ${ref.path.padRight(40)} ${display(root, ref.span.file)}:${ref.span.line}");
      }
    }
    out.writeln("${missing.length} missing");
    return exitOk;
  }
}
