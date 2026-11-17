import 'package:cerita_core/cerita_core.dart' as core;

import 'cast.dart';
import 'compiler.dart';
import 'config.dart';
import 'core_lint.dart';
import 'diagnostics.dart';
import 'model.dart';
import 'project.dart';

/// Checks a story (spec §3.1) in two layers, and reports every problem with its script file and line:
///
/// 1. Script checks: syntax, names that only exist in the scripts and YAML files (speakers, expressions),
///    missing translations and duplicate conversations.
/// 2. Everything that can be checked on engine JSON: cerita_core's `StoryLinter` runs on the compiled story
///    (authoring tools spec §1), so the engine and the toolkit share one set of story checks.
///
/// With [release], every warning is an error (PRD D2).
Future<Diagnostics> lintStory(StoryProject project, {bool release = false}) async {
  final script = Diagnostics()..addAll(project.diagnostics);
  final linter = _ScriptLinter(project, script, release);
  linter.run();

  // A partial compile, so JSON problems are reported next to script errors instead of after they are fixed.
  final compiled = compileStory(project, partial: true);
  script.addAll(compiled.diagnostics);
  if (compiled.files.isNotEmpty && linter.hasIndex) script.addAll(await lintCompiled(project, compiled.files));

  if (!release) return script;
  final strict = Diagnostics();
  for (final diagnostic in script.items) {
    strict.add(diagnostic.severity == Severity.warning
        ? Diagnostic(Severity.error, diagnostic.message, diagnostic.span)
        : diagnostic);
  }
  return strict;
}

class _ScriptLinter {
  final StoryProject project;
  final Diagnostics diagnostics;
  final bool release;
  bool hasIndex = false;

  _ScriptLinter(this.project, this.diagnostics, this.release);

  StoryConfig get config => project.config;

  void run() {
    _conversations();
    _unusedCast();
    _assetFolder();
    _translations();
    _withoutClues();
    _silentVariable();
  }

  /// `silent` on a `choice` line is a keyword, so `choice silent` is a silent choice without a variable. A script
  /// written before the keyword may have meant a variable named `silent`: reported when the story reads one.
  void _silentVariable() {
    final choices = [
      for (final conversation in project.conversations)
        for (final item in conversation.items)
          if (item is ChoiceItem && item is! EvidenceItem && item.silent && item.variable == null) item,
    ];
    if (choices.isEmpty) return;

    bool reads(String? expression) =>
        expression != null && core.ConditionEvaluator.variablesOf(expression).contains("silent");
    bool readsIn(TextHolder holder) =>
        holder.effects.any((effect) => reads(effect.expr)) ||
        holder.texts.values.any((text) => text.values.values.any((value) => value.contains("{{silent}}")));
    final read = project.conversations.any((conversation) => conversation.items.any((item) =>
        reads(item.condition) ||
        readsIn(item) ||
        (item is BranchItem && item.routes.any((route) => reads(route.condition))) ||
        (item is ChoiceItem && item.options.any((option) => reads(option.condition) || readsIn(option)))));
    if (!read) return;
    for (final choice in choices) {
      diagnostics.error(
        choice.span,
        "`silent` is a keyword here, so this choice stores no variable, but the story reads 'silent'. "
        "Name the variable differently, e.g. choice PICK silent",
      );
    }
  }

  void _conversations() {
    final keys = <String>{};
    for (final conversation in project.conversations) {
      keys.add(conversation.key);
    }
    hasIndex = keys.contains(ConversationNode.indexKey);
    if (project.conversations.isNotEmpty && !hasIndex) {
      diagnostics.error(null, "No 'index' conversation. The story starts at '@conversation index'");
    }
    // Duplicate keys are reported by compileStory, which can't write two files with one name.
  }

  /// Characters and expressions declared in profiles.yaml that no script uses. These names only exist in the
  /// toolkit, so the JSON linter can't see them.
  void _unusedCast() {
    final used = <String, Set<int>>{};
    void use(ProfileRef? ref, {bool idOnly = false}) {
      if (ref == null || ref.isPlayer) return;
      final profile = project.cast[ref.speaker];
      final indexes = used.putIfAbsent(ref.speaker, () => {});
      final index = idOnly ? null : profile?.spriteIndex(ref.expression);
      if (index != null) indexes.add(index);
    }

    for (final channel in project.channels ?? const []) {
      for (final member in channel.members) {
        used.putIfAbsent(member, () => {});
      }
    }
    for (final conversation in project.conversations) {
      for (final item in conversation.items) {
        switch (item) {
          case LineItem():
            use(item.speaker);
          case MediaItem():
            use(item.by);
          case ChoiceItem():
            use(item.by);
          case InputItem():
            use(item.by);
          case StageItem():
            for (final action in item.actions) {
              final profile = action.fields["profile"];
              if (profile is ProfileRef) use(profile, idOnly: action.idOnly);
            }
          default:
            break;
        }
      }
    }
    for (final profile in project.cast.profiles.values) {
      final indexes = used[profile.key];
      if (indexes == null) {
        diagnostics.warning(profile.span, "Character '${profile.key}' is never used");
        continue;
      }
      for (var i = 0; i < profile.expressions.length; i++) {
        if (!indexes.contains(i)) {
          diagnostics.warning(profile.spriteSpans[i], "Expression '${profile.key}:${profile.expressions[i]}' is never used");
        }
      }
    }
  }

  /// Clue checks run on the compiled story, against `clues.json`. Without `clues.yaml` there is none, and the core
  /// linter treats `clue_` variables as ordinary ones, so a `clue` line is reported here. Evidence responses are
  /// still checked by the core linter.
  void _withoutClues() {
    if (project.clues != null) return;
    void undeclared(String clue, SourceSpan span) =>
        diagnostics.error(span, "Clue '$clue' isn't declared: add it to ${ClueFile.fileName}");
    void effects(List<EffectNode> effects) {
      for (final effect in effects) {
        if (effect.clue case final clue?) undeclared(clue, effect.span);
      }
    }

    for (final conversation in project.conversations) {
      for (final item in conversation.items) {
        effects(item.effects);
        if (item is! ChoiceItem) continue;
        for (final option in item.options) {
          effects(option.effects);
        }
      }
    }
  }

  void _assetFolder() {
    if (project.assetFiles != null) return;
    final reason = project.assetsError;
    if (reason != null) {
      diagnostics.error(const SourceSpan(StoryConfig.fileName, 1), reason);
    } else if (release) {
      diagnostics.error(null, "Release checks need the asset folder: set 'assets' in cerita.yaml or pass --assets");
    } else {
      diagnostics.note(null, "Asset checks skipped: set 'assets' in cerita.yaml or pass --assets");
    }
  }

  void _translations() {
    if (!config.isMultiLocale) return;
    void check(Localized? text) {
      if (text == null || text.isPlain) return;
      for (final locale in config.locales) {
        if (!text.values.containsKey(locale)) diagnostics.warning(text.span, "Missing '$locale' text");
      }
    }

    void checkFields(TextHolder holder) {
      holder.texts.forEach((field, text) {
        if (field != "tts") check(text);
      });
    }

    for (final profile in project.cast.profiles.values) {
      check(profile.name);
      check(profile.bio);
    }
    for (final channel in project.channels ?? const []) {
      check(channel.name);
      check(channel.status);
    }
    for (final clue in project.clues?.clues ?? const <ClueDef>[]) {
      check(clue.title);
      check(clue.description);
      check(clue.chapter);
    }
    for (final conversation in project.conversations) {
      check(conversation.chapter);
      check(conversation.title);
      for (final item in conversation.items) {
        checkFields(item);
        if (item is InputItem) check(item.defaultValue);
        if (item is ChoiceItem) item.options.forEach(checkFields);
      }
    }
  }
}
