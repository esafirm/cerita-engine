import '../tools/story_graph.dart';
import '../tools/story_linter.dart';
import 'file_engine_loader.dart';

const _usage = '''
Usage: cerita <command> <story folder>

Commands:
  lint [--strict]  Checks the story. Exits with 1 on errors, or on warnings too with --strict.
  graph            Prints the story as a Mermaid flowchart.
''';

/// Runs the `cerita` command line tool and returns its exit code.
Future<int> runCli(List<String> args, {required StringSink out, StringSink? err}) async {
  final errors = err ?? out;
  final flags = args.where((arg) => arg.startsWith("--")).toSet();
  final positional = args.where((arg) => !arg.startsWith("--")).toList();
  if (positional.length != 2 || !{"lint", "graph"}.contains(positional.first)) {
    errors.write(_usage);
    return 64;
  }
  final loader = FileEngineLoader.directory(positional[1]);

  switch (positional.first) {
    case "graph":
      final conversations = [
        for (final key in await loader.listConversationKeys()) await loader.loadConversation(key),
      ];
      out.write(StoryGraph(conversations).toMermaid());
      return 0;
    default:
      final issues = await StoryLinter(loader, config: loader.config, assetExists: await loader.assetChecker()).lint();
      issues.forEach(out.writeln);
      final errorCount = issues.where((issue) => issue.isError).length;
      final warningCount = issues.length - errorCount;
      out.writeln(issues.isEmpty ? "No issues found." : "$errorCount error(s), $warningCount warning(s).");
      return errorCount > 0 || (flags.contains("--strict") && warningCount > 0) ? 1 : 0;
  }
}
