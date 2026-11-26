import 'config.dart';
import 'diagnostics.dart';
import 'model.dart';

final _speakerPattern = RegExp(r"^([a-z_][a-z0-9_]*)(?::([A-Za-z0-9_-]+))?$");
final _keyPattern = RegExp(r"^[A-Za-z0-9_]+$");
final _targetPattern = RegExp(r"^[A-Za-z0-9_]*(#[A-Za-z0-9_-]+)?$");

/// Variable names, including `persistent.*` and `meta.*` (engine-and-state §2).
final variablePattern = RegExp(r"^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)*$");
final _attrKeyPattern = RegExp(r"^([a-z_]+)(?:\.([a-z]{2,3}(?:-[A-Za-z0-9]+)?))?$");
final _textLinePattern = RegExp(r"^(?:([a-z]+) )?([a-z]{2,3}(?:-[A-Za-z0-9]+)?):(?:[ \t](.*))?$");
final _durationPattern = RegExp(r"^(\d+(?:\.\d+)?)(ms|s)?$");
final _numberPattern = RegExp(r"^-?\d+(\.\d+)?$");
final _effectLinePattern = RegExp(r"^([+-][A-Za-z_]|set\s|toggle\s|remember\s|clue\s)");
final _setBlockPattern = RegExp(r"^set(\s*$|\s+\[|\s+label=)");
final _evidenceOutcomePattern = RegExp(r"^\[(retry|fallback|timeout)\]$");
final _computedEffectPattern = RegExp(r"^(set\s+|[+-])(\S+?)\s*=\s*(.+)$");
final _stepEffectPattern = RegExp(r"^([+-])(\S+?)(?:\s+(\d+(?:\.\d+)?))?$");
final _setEffectPattern = RegExp(r"^set\s+(\S+)\s+(.+)$");
final _clueEffectPattern = RegExp(r"^clue\s+(\S+)$");
final _singleEffectPattern = RegExp(r"^(toggle|remember)\s+(\S+)$");
final _unescapePattern = RegExp(r"\\([n|\\])");

const _modes = {"VN", "CHAT", "CALL"};
const _mediaTypes = {"IMAGE", "AUDIO", "VIDEO", "CG"};
const _positions = ["far_left", "left", "center", "right", "far_right"];
const _textboxStyles = {"adv", "nvl"};
const _weathers = {"rain", "snow", "sakura"};
const _cgFocuses = [
  "center", "left", "right", "top", "bottom", "top_left", "top_right", "bottom_left", "bottom_right", //
];
const _transitions = {
  "fade", "dissolve", "fade_black", "slide_left", "slide_right", "slide_up", "zoom", "wipe_left", "wipe_right", //
  "none",
};

/// Script field names that differ from their JSON field.
const _jsonFields = {"notification": "notification_text"};

/// Parses `.cerita` scripts (spec §2) into [ScriptFile]s. Problems go to [diagnostics]; parsing carries on
/// after each one so every problem in a file is reported.
class ScriptParser {
  final StoryConfig config;
  final Diagnostics diagnostics;

  ScriptParser(this.config, this.diagnostics);

  ConversationNode? _conversation;

  /// What indented lines belong to: an item, an option, [_discard] after a broken header, or `null` (none).
  Object? _body;
  ChoiceItem? _choice;

  /// The `SET` that column-0 effect lines are added to, while they follow each other.
  SetItem? _inlineSet;

  /// Stages with at least one action line, valid or not.
  final Set<StageItem> _stagesWithActions = {};

  static final _discard = Object();

  ScriptFile parse(String path, String source) {
    _conversation = null;
    _body = null;
    _choice = null;
    _inlineSet = null;
    _stagesWithActions.clear();
    final script = ScriptFile(path);
    final lines = source.replaceFirst("﻿", "").split("\n");
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].endsWith("\r") ? lines[i].substring(0, lines[i].length - 1) : lines[i];
      final span = SourceSpan(path, i + 1);
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith("#")) continue;
      if (line.startsWith(" ") || line.startsWith("\t")) {
        _bodyLine(trimmed, span);
      } else {
        _statement(line.trimRight(), span, script);
      }
    }
    for (final conversation in script.conversations) {
      _validate(conversation);
    }
    return script;
  }

  void _error(SourceSpan span, String message) => diagnostics.error(span, message);

  /* Statements */

  void _statement(String line, SourceSpan span, ScriptFile script) {
    if (line.startsWith("?")) {
      _option(line.substring(1), span);
      return;
    }
    _choice = null;
    _body = _discard;
    if (_effectLinePattern.hasMatch(line) && !_setBlockPattern.hasMatch(line)) return _inlineEffect(line, span);
    _inlineSet = null;

    final tokens = _tokenize(line, span);
    if (tokens == null || tokens.isEmpty) return;
    final head = tokens.first;
    if (head is! _Word) {
      _error(span, "A statement starts with a keyword or a speaker");
      return;
    }
    final st = _Statement(this, span, tokens.skip(1));
    final word = head.text;

    if (word == "@conversation") return _conversationHeader(st, script);
    if (word == "@scene") return _sceneHeader(st);
    if (word.startsWith("@")) return _error(span, "Unknown directive '$word'");

    final conversation = _conversation;
    if (conversation == null) return _error(span, "Statements must come after an @conversation line");

    final ItemNode? item = switch (word) {
      "->" || "call" => _jump(st, isCall: word == "call"),
      "return" => ReturnItem(span),
      "set" => SetItem(span),
      "stage" => _stage(st),
      "narration" || "system" || "timestamp" => _narration(st, word),
      "media" => _media(st),
      "choice" => _choiceItem(st),
      "input" => _input(st),
      "wait" => _wait(st),
      "branch" => BranchItem(span),
      "ending" => _ending(st),
      "evidence" => _evidenceItem(st),
      _ => _speakerLine(st, word),
    };
    if (item == null) return;
    item.condition = st.condition();
    item.label = st.take("label");
    st.finish();
    conversation.items.add(item);
    _body = item;
    if (item is ChoiceItem) _choice = item;
  }

  /// An effect line at column 0 becomes a `SET`. Effect lines that follow each other share one.
  void _inlineEffect(String line, SourceSpan span) {
    final conversation = _conversation;
    if (conversation == null) return _error(span, "Statements must come after an @conversation line");
    _body = null;
    final effect = _effect(line, span);
    if (effect == null) return;
    var set = _inlineSet;
    if (set == null || conversation.items.lastOrNull != set) {
      set = SetItem(span);
      conversation.items.add(set);
      _inlineSet = set;
    }
    set.effects.add(effect);
  }

  void _conversationHeader(_Statement st, ScriptFile script) {
    final checkpoint = st.flag("checkpoint");
    final key = st.next();
    if (key == null || !_keyPattern.hasMatch(key)) {
      _error(
        st.span,
        key == null
            ? "@conversation needs a key, e.g. @conversation day1"
            : "Invalid conversation key '$key': use letters, digits and _",
      );
      // Statements below still parse, so their problems are reported, but they belong to no conversation.
      _conversation = ConversationNode("", st.span);
      _body = null;
      return;
    }
    final conversation = ConversationNode(key, st.span)
      ..checkpoint = checkpoint
      ..conversationId = st.take("id")
      ..chapter = st.localized("chapter")
      ..title = st.localized("title");
    st.finish(allowCondition: false);
    script.conversations.add(conversation);
    _conversation = conversation;
    _body = null;
  }

  void _sceneHeader(_Statement st) {
    final conversation = _conversation;
    if (conversation == null) return _error(st.span, "@scene must come after an @conversation line");
    if (conversation.scene != null) return _error(st.span, "A conversation has only one @scene");
    if (conversation.items.isNotEmpty) return _error(st.span, "@scene must come before the first statement");
    final mode = st.next();
    if (mode == null || !_modes.contains(mode)) {
      return _error(st.span, "@scene needs a mode: VN, CHAT or CALL");
    }
    final scene = SceneNode(st.span, mode)
      ..background = st.take("bg")
      ..music = st.take("music")
      ..ambience = st.take("ambience")
      ..ring = st.take("ring")
      ..textbox = st.choose("textbox", _textboxStyles)
      ..channel = st.take("channel")
      ..time = st.take("time");
    final hangUp = st.take("hangup");
    if (hangUp != null) scene.hangUp = _target(hangUp, st.span, "hangup");
    scene.stay = st.localized("stay");
    // `status=none` hides the channel status for this scene, any other text replaces it.
    final status = st.localized("status");
    if (status != null && status.values.length == 1 && status.values.values.single == "none") {
      scene.hideStatus = true;
    } else {
      scene.status = status;
    }
    final day = st.take("day");
    if (day != null) {
      scene.day = int.tryParse(day);
      if (scene.day == null) _error(st.span, "day must be a whole number, not '$day'");
    }
    for (final (set, name) in [(scene.ring != null, "ring"), (hangUp != null, "hangup"), (scene.stay != null, "stay")]) {
      if (set && mode != "CALL") _error(st.span, "$name is only for CALL scenes");
    }
    if (hangUp != null && scene.stay != null) {
      _error(st.span, "stay is for a call that can't be hung up, so not with hangup");
    }
    st.finish(allowCondition: false);
    conversation.scene = scene;
    _body = null;
  }

  TargetRef? _target(String? raw, SourceSpan span, String what) {
    if (raw == null || raw.isEmpty || !_targetPattern.hasMatch(raw)) {
      _error(span, raw == null || raw.isEmpty ? "$what needs a target" : "Invalid target '$raw'. Use day2, #label or day2#label");
      return null;
    }
    return TargetRef(raw, span);
  }

  ItemNode? _jump(_Statement st, {required bool isCall}) {
    final target = _target(st.next(), st.span, isCall ? "call" : "->");
    return target == null ? null : JumpItem(st.span, target, isCall: isCall);
  }

  ItemNode _stage(_Statement st) {
    final item = StageItem(st.span);
    final wait = st.duration("wait");
    if (wait != null) item.waitMs = wait;
    return item;
  }

  ItemNode _narration(_Statement st, String word) =>
      NarrationItem(st.span, word == "narration" ? null : word)..sfx = st.take("sfx");

  ItemNode? _media(_Statement st) {
    final mediaType = st.next();
    if (mediaType == null || !_mediaTypes.contains(mediaType)) {
      _error(st.span, "media needs a type: IMAGE, AUDIO, VIDEO or CG");
      return null;
    }
    final file = st.next();
    if (file == null) {
      _error(st.span, "media needs a file name");
      return null;
    }
    return MediaItem(st.span, mediaType, file)
      ..by = st.profile("by")
      ..unlock = st.take("unlock")
      ..typingMs = st.duration("typing")
      ..sfx = st.take("sfx");
  }

  ItemNode? _choiceItem(_Statement st) {
    // `silent` is a keyword here, never a variable: `choice silent` is a silent choice without a variable. The
    // linter reports a script that reads a variable named `silent` next to one.
    final silent = st.flag("silent");
    final variable = st.next();
    if (variable == "silent") {
      _error(st.span, "`silent` is a keyword here, name the variable differently");
    } else if (variable != null && !variablePattern.hasMatch(variable)) {
      _error(st.span, "Invalid variable name '$variable'");
    }
    return ChoiceItem(st.span, variable)
      ..by = st.profile("by")
      ..timeoutMs = st.duration("timeout")
      ..silent = silent;
  }

  ItemNode? _evidenceItem(_Statement st) {
    final variable = st.next();
    if (variable != null && !variablePattern.hasMatch(variable)) {
      _error(st.span, "Invalid variable name '$variable'");
    }
    final item = EvidenceItem(st.span, variable)
      ..by = st.profile("by")
      ..timeoutMs = st.duration("timeout");
    final retries = st.take("retries");
    if (retries != null) {
      item.retries = int.tryParse(retries);
      if (item.retries == null || item.retries! < 0) _error(st.span, "retries must be a whole number, not '$retries'");
    }
    return item;
  }

  ItemNode? _input(_Statement st) {
    final variable = st.next();
    if (variable == null || !variablePattern.hasMatch(variable)) {
      _error(
        st.span,
        variable == null ? "input needs a variable, e.g. input NAME" : "Invalid variable name '$variable'",
      );
      return null;
    }
    final item = InputItem(st.span, variable)
      ..defaultValue = st.localized("default")
      ..by = st.profile("by")
      ..keyboard = st.choose("keyboard", const {"text", "digits"});
    if (item.keyboard == "text") item.keyboard = null;
    // `length=4` is short for `min_length=4 max_length=4`.
    final length = _inputLength(st, "length");
    var min = _inputLength(st, "min_length");
    var max = _inputLength(st, "max_length");
    if (length != null) {
      if (min != null || max != null) _error(st.span, "Use length= or min_length= and max_length=, not both");
      min = max = length;
    }
    if (min != null && max != null && min > max) {
      _error(st.span, "min_length ($min) is more than max_length ($max)");
    }
    return item
      ..minLength = min
      ..maxLength = max;
  }

  /// A positive whole number of characters for an input's `length=`, `min_length=` or `max_length=`.
  int? _inputLength(_Statement st, String key) {
    final raw = st.take(key);
    if (raw == null) return null;
    final value = int.tryParse(raw);
    if (value == null || value < 1) {
      _error(st.span, "$key must be a whole number from 1, not '$raw'");
      return null;
    }
    return value;
  }

  ItemNode? _wait(_Statement st) {
    final raw = st.next();
    final duration = raw == null ? null : parseDuration(raw);
    if (duration == null) {
      _error(st.span, raw == null ? "wait needs a duration, e.g. wait 1.5s" : "Invalid duration '$raw'");
      return null;
    }
    return WaitItem(st.span, duration);
  }

  ItemNode? _ending(_Statement st) {
    final id = st.next();
    final category = st.next();
    if (id == null) {
      _error(st.span, "ending needs an id and a category, e.g. ending end_true TRUE");
      return null;
    }
    if (category == null || !EndingItem.categories.contains(category)) {
      _error(st.span, "ending needs a category: ${EndingItem.categories.join(", ")}");
      return null;
    }
    return EndingItem(st.span, id, category);
  }

  ItemNode? _speakerLine(_Statement st, String word) {
    final match = _speakerPattern.firstMatch(word);
    if (match == null) {
      _error(st.span, "Unknown statement '$word'");
      return null;
    }
    final item = LineItem(st.span, ProfileRef(match.group(1)!, match.group(2), st.span));
    for (final position in _positions) {
      if (st.modifier(position)) {
        if (item.position != null) _error(st.span, "A line has only one position");
        item.position = position;
      }
    }
    item.offstage = st.modifier("offstage");
    if (item.offstage && item.position != null) _error(st.span, "An [offstage] line has no position");
    item
      ..typingMs = st.duration("typing")
      ..sfx = st.take("sfx")
      ..voice = st.take("voice");
    return item;
  }

  void _option(String rest, SourceSpan span) {
    final choice = _choice;
    if (choice == null) {
      _error(span, "An option must follow a choice or another option");
      _body = _discard;
      return;
    }
    if (choice is EvidenceItem) return _evidenceOption(choice, rest.trim(), span);
    final option = OptionNode(span);
    var text = rest.trim();
    while (text.endsWith("]")) {
      final open = _openingBracket(text);
      if (open < 0) break;
      final inner = text.substring(open + 1, text.length - 1).trim();
      if (inner == "default") {
        if (option.isDefault) _error(span, "Duplicate [default]");
        option.isDefault = true;
      } else if (inner == "once") {
        option.once = true;
      } else if (inner == "memory_marker") {
        option.memoryMarker = true;
      } else if (inner == "silent") {
        option.silent = true;
      } else if (inner.startsWith("if ")) {
        if (option.condition != null) _error(span, "An option has only one [if]");
        option.condition = inner.substring(3).trim();
      } else {
        break;
      }
      text = text.substring(0, open).trimRight();
    }
    if (text.isNotEmpty) {
      final parts = config.isMultiLocale ? _splitOptions(text) : [text];
      if (parts.length > config.locales.length) {
        _error(span, "${parts.length} texts for ${config.locales.length} locales (${config.locales.join(" | ")})");
      }
      final localized = Localized(span);
      for (var i = 0; i < parts.length && i < config.locales.length; i++) {
        final part = unescapeText(parts[i].trim());
        if (part.isNotEmpty) localized.set(config.locales[i], part, span);
      }
      option.texts["text"] = localized;
    }
    choice.options.add(option);
    _body = option;
  }

  /// A `?` line under `evidence`: a clue id for a response, or `[retry]`, `[fallback]` or `[timeout]`.
  void _evidenceOption(EvidenceItem evidence, String text, SourceSpan span) {
    final option = OptionNode(span);
    final outcome = _evidenceOutcomePattern.firstMatch(text)?.group(1);
    if (outcome != null) {
      if (evidence.outcome(outcome) != null) _error(span, "An evidence question has only one [$outcome]");
      option.outcome = outcome;
    } else if (_keyPattern.hasMatch(text)) {
      option.clue = text;
    } else {
      _error(span, "An evidence answer is a clue id, or [retry], [fallback] or [timeout]");
      _body = _discard;
      return;
    }
    evidence.options.add(option);
    _body = option;
  }

  int _openingBracket(String text) {
    var depth = 0;
    String? quote;
    for (var i = text.length - 1; i >= 0; i--) {
      final char = text[i];
      if (quote != null) {
        if (char == quote) quote = null;
        continue;
      }
      if (char == "'" || char == '"') {
        quote = char;
      } else if (char == "]") {
        depth++;
      } else if (char == "[") {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  List<String> _splitOptions(String text) {
    final parts = <String>[];
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (text[i] == "\\" && i + 1 < text.length && (text[i + 1] == "|" || text[i + 1] == "\\")) {
        buffer.write("\\");
        buffer.write(text[i + 1]);
        i++;
      } else if (text[i] == "|") {
        parts.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(text[i]);
      }
    }
    parts.add(buffer.toString());
    return parts;
  }

  /* Body lines */

  void _bodyLine(String content, SourceSpan span) {
    final body = _body;
    if (identical(body, _discard)) return;
    if (body == null) return _error(span, "Indented line outside a statement");
    if (body is BranchItem) return _routeLine(body, content, span);
    if (body is StageItem && !_effectLinePattern.hasMatch(content)) return _stageAction(body, content, span);
    final holder = body as TextHolder;
    if (holder is OptionNode && (holder.clue != null || holder.outcome != null)) {
      if (_textLinePattern.hasMatch(content)) {
        return _error(span, "An evidence answer has no text: the player presents the clue");
      }
      if (content.startsWith("value ") || content == "value") {
        return _error(span, "value doesn't go under an evidence answer: the presented clue's id is stored");
      }
    }

    final text = _textLinePattern.firstMatch(content);
    if (text != null) return _textLine(holder, text, span);

    if (content.startsWith("delivery:")) {
      final delivery = content.substring("delivery:".length).trim();
      switch (holder) {
        case LineItem():
          holder.delivery = delivery;
        case MediaItem(isVoiceNote: true):
          holder.delivery = delivery;
        default:
          _error(span, "delivery: only goes on spoken lines and voice notes");
      }
      return;
    }
    if (content.startsWith("->")) {
      if (holder is! OptionNode) return _error(span, "A target only goes under a choice option or in a branch");
      if (holder.target != null) return _error(span, "An option has only one target");
      holder.target = _target(content.substring(2).trim(), span, "->");
      return;
    }
    if (content.startsWith("value ") || content == "value") {
      if (holder is! OptionNode) return _error(span, "value only goes under a choice option");
      final raw = content.substring(5).trim();
      if (raw.isEmpty) return _error(span, "value needs a value");
      if (holder.hasValue) return _error(span, "An option has only one value");
      holder
        ..value = parseLiteral(raw)
        ..hasValue = true;
      return;
    }
    final effect = _effect(content, span);
    if (effect != null) {
      holder.effects.add(effect);
      return;
    }
    if (!_effectLinePattern.hasMatch(content)) _error(span, "Unknown line '$content'");
  }

  void _textLine(TextHolder holder, RegExpMatch match, SourceSpan span) {
    final (main, allowed) = _fields(holder);
    if (allowed.isEmpty) return _error(span, "No text goes under this statement");
    final field = match.group(1) ?? main;
    final locale = match.group(2)!;
    final value = unescapeText((match.group(3) ?? "").trim());
    if (!allowed.contains(field)) return _error(span, "'$field' text doesn't go here");
    if (!config.locales.contains(locale)) {
      return _error(span, "Unknown locale '$locale'. The story's locales are ${config.locales.join(", ")}");
    }
    if (value.isEmpty) return _error(span, "Empty text");
    final localized = holder.texts.putIfAbsent(_jsonFields[field] ?? field, () => Localized(span));
    if (localized.values.containsKey(locale)) return _error(span, "Duplicate '$locale' text");
    localized.set(locale, value, span);
  }

  (String, Set<String>) _fields(TextHolder holder) => switch (holder) {
    LineItem() => ("text", const {"text", "tts"}),
    MediaItem(isVoiceNote: true) => ("transcript", const {"title", "caption", "transcript", "tts"}),
    MediaItem() => ("caption", const {"title", "caption", "transcript"}),
    WaitItem() => ("notification", const {"notification"}),
    EndingItem() => ("title", const {"title", "summary"}),
    BranchItem() || JumpItem() || ReturnItem() || SetItem() || StageItem() => ("text", const <String>{}),
    _ => ("text", const {"text"}),
  };

  void _routeLine(BranchItem branch, String content, SourceSpan span) {
    if (_effectLinePattern.hasMatch(content)) {
      return _error(span, "Effects on a branch never run: the engine jumps without executing it");
    }
    final arrow = content.lastIndexOf("->");
    if (arrow < 0) return _error(span, "A branch route is 'if <condition> -> <target>' or '-> <target>'");
    final head = content.substring(0, arrow).trim();
    final ref = _target(content.substring(arrow + 2).trim(), span, "->");
    if (ref == null) return;
    if (head.isEmpty) {
      if (branch.fallback != null) return _error(span, "A branch has only one fallback");
      branch.fallback = ref;
    } else if (head.startsWith("if ")) {
      if (branch.fallback != null) _error(span, "Routes after the fallback never run");
      branch.routes.add(BranchRoute(head.substring(3).trim(), ref, span));
    } else {
      _error(span, "A branch route is 'if <condition> -> <target>' or '-> <target>'");
    }
  }

  /// One action under `stage` (data schema §4.12): the action name, positional values, then `key=value`s.
  void _stageAction(StageItem stage, String content, SourceSpan span) {
    _stagesWithActions.add(stage);
    final tokens = _tokenize(content, span);
    if (tokens == null || tokens.isEmpty || tokens.first is! _Word) {
      return _error(span, "A stage action starts with its name, e.g. 'show nora:smile left'");
    }
    final name = (tokens.first as _Word).text;
    final errorsBefore = diagnostics.items.length;
    final st = _Statement(this, span, tokens.skip(1));
    final action = StageAction(name, span);
    final fields = action.fields;

    String? required(String what) {
      final value = st.next();
      if (value == null) _error(span, "$name needs $what");
      return value;
    }

    /// A file or name, or `none` for null.
    void nullable(String field, String what) {
      final value = required(what);
      if (value != null) fields[field] = value == "none" ? null : value;
    }

    void profile({required bool idOnly}) {
      final raw = required("a character");
      if (raw == null) return;
      final match = _speakerPattern.firstMatch(raw);
      if (match == null) return _error(span, "Invalid character '$raw'");
      if (idOnly && match.group(2) != null) _error(span, "$name takes a character without an expression");
      fields["profile"] = ProfileRef(match.group(1)!, match.group(2), span);
      action.idOnly = idOnly;
    }

    void position({required bool isRequired}) {
      final value = st.next();
      if (value == null) {
        if (isRequired) _error(span, "$name needs a position: ${_positions.join(", ")}");
      } else if (_positions.contains(value)) {
        fields["position"] = value;
      } else {
        _error(span, "Unknown position '$value'. Use ${_positions.join(", ")}");
      }
    }

    num? number(String key) {
      final raw = st.take(key);
      if (raw == null) return null;
      final value = parseLiteral(raw);
      if (value is num) return value;
      _error(span, "$key must be a number");
      return null;
    }

    /// `zoom=` and `focus=` of a CG camera.
    void cgCamera() {
      final zoom = number("zoom");
      if (zoom != null) {
        zoom >= 1 ? fields["zoom"] = zoom : _error(span, "zoom must be 1 or more: below 1 the CG no longer fills the screen");
      }
      final focus = st.take("focus");
      if (focus != null) {
        _cgFocuses.contains(focus)
            ? fields["focus"] = focus
            : _error(span, "Unknown focus '$focus'. Use ${_cgFocuses.join(", ")}");
      }
    }

    switch (name) {
      case "show":
        profile(idOnly: false);
        position(isRequired: false);
      case "hide":
        profile(idOnly: true);
      case "clear" || "page":
        break;
      case "move":
        profile(idOnly: true);
        position(isRequired: true);
      case "background":
        nullable("image", "an image or none");
      case "cg":
        nullable("image", "an image or none");
        if (fields["image"] == null) {
          if (st.take("unlock") != null) _error(span, "cg none has nothing to unlock");
          for (final key in const ["title", "caption"]) {
            if (st.localized(key) != null) _error(span, "cg none has no $key");
          }
        } else {
          final unlock = st.take("unlock");
          if (unlock != null) fields["unlock_id"] = unlock;
          for (final key in const ["title", "caption"]) {
            final text = st.localized(key);
            if (text == null) continue;
            unlock == null ? _error(span, "cg $key= names a Gallery entry, so it needs unlock=") : fields[key] = text;
          }
        }
        cgCamera();
      case "cg_move":
        cgCamera();
        if (!fields.containsKey("zoom") && !fields.containsKey("focus")) {
          _error(span, "cg_move needs zoom= or focus=, e.g. cg_move zoom=1.3 focus=top duration=8s");
        }
      case "music" || "ambience":
        nullable("file", "a file or none");
      case "sound":
        final file = required("a file");
        if (file != null) fields["file"] = file;
      case "weather":
        final weather = required("rain, snow, sakura or none");
        if (weather != null && weather != "none" && !_weathers.contains(weather)) {
          _error(span, "Unknown weather '$weather'. Use rain, snow, sakura or none");
        }
        if (weather != null) fields["name"] = weather == "none" ? null : weather;
      case "shake":
        final intensity = number("intensity");
        if (intensity != null) fields["intensity"] = intensity;
      case "flash":
        final color = st.take("color");
        if (color != null) fields["color"] = color;
      case "zoom":
        final scale = st.next();
        if (scale != null) {
          final value = parseLiteral(scale);
          value is num ? fields["scale"] = value : _error(span, "zoom takes a scale, e.g. zoom 1.2");
        }
        final focus = st.take("focus");
        if (focus != null) {
          _positions.contains(focus) ? fields["focus"] = focus : _error(span, "Unknown focus '$focus'");
        }
      case "textbox":
        final style = required("adv or nvl");
        if (style != null) {
          _textboxStyles.contains(style) ? fields["style"] = style : _error(span, "textbox takes adv or nvl");
        }
      default:
        return _error(span, "Unknown stage action '$name'");
    }
    final transition = st.choose("transition", _transitions);
    if (transition != null) fields["transition"] = transition;
    final duration = st.duration("duration");
    if (duration != null) fields["duration_ms"] = duration;
    if (name == "music" || name == "ambience") {
      final fade = st.duration("fade");
      if (fade != null) fields["fade_ms"] = fade;
    }
    st.finish(allowCondition: false);
    // A broken action is left out, so a partial compile for the linter still loads.
    if (diagnostics.items.length == errorsBefore) stage.actions.add(action);
  }

  EffectNode? _effect(String content, SourceSpan span) {
    final computed = _computedEffectPattern.firstMatch(content);
    if (computed != null) {
      final head = computed.group(1)!.trim();
      final op = switch (head) { "set" => "set", "+" => "add", _ => "subtract" };
      if (!_checkVariable(computed.group(2)!, span)) return null;
      return EffectNode(computed.group(2)!, op, span, expr: computed.group(3)!.trim());
    }
    final step = _stepEffectPattern.firstMatch(content);
    if (step != null) {
      if (!_checkVariable(step.group(2)!, span)) return null;
      final amount = step.group(3) == null ? 1 : parseLiteral(step.group(3)!);
      return EffectNode(step.group(2)!, step.group(1) == "+" ? "add" : "subtract", span, value: amount, hasValue: true);
    }
    final set = _setEffectPattern.firstMatch(content);
    if (set != null) {
      if (!_checkVariable(set.group(1)!, span)) return null;
      return EffectNode(set.group(1)!, "set", span, value: parseLiteral(set.group(2)!.trim()), hasValue: true);
    }
    final clue = _clueEffectPattern.firstMatch(content);
    if (clue != null) {
      final id = clue.group(1)!;
      if (!_keyPattern.hasMatch(id)) {
        _error(span, "Invalid clue id '$id': use letters, digits and _");
        return null;
      }
      return EffectNode("${EffectNode.cluePrefix}$id", "set", span, value: true, hasValue: true, isClue: true);
    }
    final single = _singleEffectPattern.firstMatch(content);
    if (single != null) {
      if (!_checkVariable(single.group(2)!, span)) return null;
      return EffectNode(single.group(2)!, single.group(1) == "toggle" ? "toggle" : EffectNode.metaSet, span);
    }
    if (_effectLinePattern.hasMatch(content)) _error(span, "Invalid effect '$content'");
    return null;
  }

  bool _checkVariable(String name, SourceSpan span) {
    if (variablePattern.hasMatch(name)) return true;
    _error(span, "Invalid variable name '$name'");
    return false;
  }

  /// Required text and parts that the engine would fail to load without.
  void _validate(ConversationNode conversation) {
    String? missing(ItemNode item) => switch (item) {
      LineItem() || NarrationItem() => item.texts["text"] == null ? "a line needs text" : null,
      ChoiceItem() => item.texts["text"] == null ? "a choice needs a prompt" : null,
      InputItem() => item.texts["text"] == null ? "an input needs a prompt" : null,
      EndingItem() => item.texts["title"] == null ? "an ending needs a title" : null,
      _ => null,
    };
    for (final item in conversation.items) {
      final problem = missing(item);
      if (problem != null) _error(item.span, "Missing text: $problem, e.g. '  ${config.sourceLocale}: ...'");
      if (item is StageItem && !_stagesWithActions.contains(item)) _error(item.span, "A stage needs at least one action");
      if (item is SetItem && item.effects.isEmpty) _error(item.span, "A set needs at least one effect");
      // The core linter reports an evidence question without responses.
      if (item is ChoiceItem && item is! EvidenceItem) {
        if (item.options.isEmpty) _error(item.span, "A choice needs at least one '?' option");
        for (final option in item.options) {
          if (option.texts["text"]?.values.isEmpty ?? true) _error(option.span, "Missing text: an option needs text");
        }
        if (item.options.where((option) => option.isDefault).length > 1) {
          _error(item.span, "Only one option can be [default]");
        }
      }
    }
  }

  /* Tokens */

  List<_Token>? _tokenize(String line, SourceSpan span) {
    final tokens = <_Token>[];
    var i = 0;
    while (i < line.length) {
      final char = line[i];
      if (char == " " || char == "\t") {
        i++;
        continue;
      }
      if (char == "[") {
        final close = _closingBracket(line, i);
        if (close < 0) {
          _error(span, "Missing ']'");
          return null;
        }
        tokens.add(_Modifier(line.substring(i + 1, close).trim()));
        i = close + 1;
        continue;
      }
      final buffer = StringBuffer();
      int? equals;
      while (i < line.length && line[i] != " " && line[i] != "\t" && line[i] != "[") {
        if (line[i] == "=" && equals == null) equals = buffer.length;
        if (line[i] == '"') {
          i++;
          while (i < line.length && line[i] != '"') {
            if (line[i] == "\\" && i + 1 < line.length) {
              if (line[i + 1] == '"') {
                buffer.write('"');
              } else {
                // Keep `\n`, `\\`, `\|` intact so `unescapeText` interprets them once.
                buffer.write("\\");
                buffer.write(line[i + 1]);
              }
              i += 2;
            } else {
              buffer.write(line[i]);
              i++;
            }
          }
          if (i >= line.length) {
            _error(span, "Missing closing quote");
            return null;
          }
          i++;
          continue;
        }
        buffer.write(line[i]);
        i++;
      }
      final word = buffer.toString();
      final key = equals == null ? null : _attrKeyPattern.firstMatch(word.substring(0, equals));
      if (equals != null && equals > 0 && key != null) {
        tokens.add(_Attr(key.group(1)!, key.group(2), word.substring(equals + 1)));
      } else {
        tokens.add(_Word(word));
      }
    }
    return tokens;
  }

  int _closingBracket(String line, int open) {
    var depth = 0;
    String? quote;
    for (var i = open; i < line.length; i++) {
      final char = line[i];
      if (quote != null) {
        if (char == quote) quote = null;
        continue;
      }
      if (char == "'" || char == '"') {
        quote = char;
      } else if (char == "[") {
        depth++;
      } else if (char == "]") {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }
}

/// `1500`, `1500ms` or `1.5s` in milliseconds, or `null` when invalid.
int? parseDuration(String raw) {
  final match = _durationPattern.firstMatch(raw);
  if (match == null) return null;
  final value = double.parse(match.group(1)!);
  return (match.group(2) == "s" ? value * 1000 : value).round();
}

/// A number, `true`, `false`, a `"quoted string"` or a bare word.
Object parseLiteral(String raw) {
  if (raw == "true") return true;
  if (raw == "false") return false;
  if (_numberPattern.hasMatch(raw)) return raw.contains(".") ? double.parse(raw) : int.parse(raw);
  if (raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')) {
    return raw.substring(1, raw.length - 1).replaceAll(r'\"', '"').replaceAll(r"\\", r"\");
  }
  return raw;
}

/// `\n` is a line break, `\|` a literal bar in option text and `\\` a backslash.
String unescapeText(String text) => text.replaceAllMapped(_unescapePattern, (match) {
  return switch (match.group(1)) {
    "n" => "\n",
    final other => other!,
  };
});

sealed class _Token {}

class _Word extends _Token {
  final String text;

  _Word(this.text);
}

class _Attr extends _Token {
  final String key;
  final String? locale;
  final String value;

  _Attr(this.key, this.locale, this.value);
}

class _Modifier extends _Token {
  final String text;

  _Modifier(this.text);
}

/// The words, attributes and modifiers after a statement keyword. Handlers take what they understand, and
/// [finish] reports whatever is left.
class _Statement {
  final ScriptParser parser;
  final SourceSpan span;
  final List<String> _words = [];
  final List<_Attr> _attrs = [];
  final List<String> _modifiers = [];

  _Statement(this.parser, this.span, Iterable<_Token> tokens) {
    for (final token in tokens) {
      switch (token) {
        case _Word():
          _words.add(token.text);
        case _Attr():
          if (_attrs.any((attr) => attr.key == token.key && attr.locale == token.locale)) {
            parser._error(span, "Duplicate attribute '${token.key}${token.locale == null ? "" : ".${token.locale}"}'");
          }
          _attrs.add(token);
        case _Modifier():
          _modifiers.add(token.text);
      }
    }
  }

  String? next() => _words.isEmpty ? null : _words.removeAt(0);

  bool flag(String word) => _words.remove(word);

  bool modifier(String text) => _modifiers.remove(text);

  String? condition() {
    final conditions = _modifiers.where((m) => m.startsWith("if ")).toList();
    if (conditions.isEmpty) return null;
    if (conditions.length > 1) parser._error(span, "A statement has only one [if]");
    _modifiers.removeWhere((m) => m.startsWith("if "));
    return conditions.first.substring(3).trim();
  }

  String? take(String key) {
    final index = _attrs.indexWhere((attr) => attr.key == key && attr.locale == null);
    if (index < 0) return null;
    final value = _attrs.removeAt(index).value;
    if (value.isEmpty) parser._error(span, "Empty $key=");
    return value;
  }

  Map<String, String> _takeLocales(String key) {
    final result = <String, String>{};
    for (final attr in _attrs.where((attr) => attr.key == key && attr.locale != null).toList()) {
      _attrs.remove(attr);
      if (!parser.config.locales.contains(attr.locale)) {
        parser._error(span, "Unknown locale '${attr.locale}' in $key.${attr.locale}=");
      }
      result[attr.locale!] = attr.value;
    }
    return result;
  }

  /// `key="source text" key.en="English text"`.
  Localized? localized(String key) {
    final plain = take(key);
    final perLocale = _takeLocales(key);
    if (plain == null && perLocale.isEmpty) return null;
    final result = Localized(span);
    if (plain != null) result.set(parser.config.sourceLocale, unescapeText(plain), span);
    perLocale.forEach((locale, text) => result.set(locale, unescapeText(text), span));
    return result;
  }

  /// `key=value` where value must be one of [allowed].
  String? choose(String key, Set<String> allowed) {
    final value = take(key);
    if (value != null && !allowed.contains(value)) {
      parser._error(span, "Unknown $key '$value'. Use ${allowed.join(", ")}");
      return null;
    }
    return value;
  }

  int? duration(String key) {
    final raw = take(key);
    if (raw == null) return null;
    final value = parseDuration(raw);
    if (value == null) parser._error(span, "Invalid duration $key=$raw. Use e.g. 1500, 1500ms or 1.5s");
    return value;
  }

  ProfileRef? profile(String key) {
    final raw = take(key);
    if (raw == null) return null;
    final match = _speakerPattern.firstMatch(raw);
    if (match == null) {
      parser._error(span, "Invalid speaker $key=$raw");
      return null;
    }
    return ProfileRef(match.group(1)!, match.group(2), span);
  }

  void finish({bool allowCondition = true}) {
    if (!allowCondition && condition() != null) parser._error(span, "[if] doesn't go on this line");
    for (final attr in _attrs) {
      parser._error(span, "Unknown attribute '${attr.key}${attr.locale == null ? "" : ".${attr.locale}"}'");
    }
    for (final word in _words) {
      parser._error(span, "Unexpected '$word'");
    }
    for (final modifier in _modifiers) {
      parser._error(span, "Unknown modifier '[$modifier]'");
    }
  }
}
