import 'diagnostics.dart';

/// Text written per locale. With one locale it compiles to a plain string, otherwise to `{locale: text}` (CE-01).
class Localized {
  final SourceSpan span;
  final Map<String, String> values = {};
  final Map<String, SourceSpan> spans = {};

  /// A plain YAML value (a name in profiles.yaml): the same in every locale, so it stays a plain string and isn't
  /// checked for translations.
  bool isPlain = false;

  Localized(this.span);

  Localized.single(this.span, String locale, String text) {
    set(locale, text, span);
  }

  void set(String locale, String text, SourceSpan at) {
    values[locale] = text;
    spans[locale] = at;
  }

  /// The text in [locale], falling back to [fallback] (the source locale) and then to any text, like the engine.
  String? textFor(String locale, String fallback) => values[locale] ?? values[fallback] ?? values.values.firstOrNull;
}

/// The CE-01 voice convention (data schema §5.4): for `name.mp3` the player first tries `name.<locale>.mp3`,
/// then `name.mp3`.
String localeVariant(String file, String locale) {
  final dot = file.lastIndexOf(".");
  final slash = file.lastIndexOf("/");
  return dot > slash + 1 ? "${file.substring(0, dot)}.$locale${file.substring(dot)}" : "$file.$locale";
}

class ProfileRef {
  static const player = "player";

  final String speaker;
  final String? expression;
  final SourceSpan span;

  const ProfileRef(this.speaker, this.expression, this.span);

  bool get isPlayer => speaker == player;

  @override
  String toString() => expression == null ? speaker : "$speaker:$expression";
}

/// A `target`: `conv`, `#label` in the current conversation, or `conv#label` (data schema §5).
class TargetRef {
  final String key;
  final SourceSpan span;

  const TargetRef(this.key, this.span);

  /// The conversation this points at: [from] for a `#label`.
  String conversation(String from) {
    final hash = key.indexOf("#");
    final conversation = hash < 0 ? key : key.substring(0, hash);
    return conversation.isEmpty ? from : conversation;
  }

  String? get label {
    final hash = key.indexOf("#");
    return hash < 0 ? null : key.substring(hash + 1);
  }
}

class EffectNode {
  static const metaSet = "meta_set";

  final String variable;
  final String op;
  final Object? value;
  final bool hasValue;

  /// Expression the engine evaluates when the effect runs, in place of [value].
  final String? expr;
  final SourceSpan span;

  const EffectNode(this.variable, this.op, this.span, {this.value, this.hasValue = false, this.expr});
}

/// Something with localized text fields and effects: an item or a choice option.
abstract class TextHolder {
  SourceSpan get span;

  /// Localized text per JSON field name (`text`, `caption`, `title`...). `tts` is toolkit-only.
  Map<String, Localized> get texts;

  List<EffectNode> get effects;
}

sealed class ItemNode implements TextHolder {
  @override
  final SourceSpan span;
  @override
  final Map<String, Localized> texts = {};
  @override
  final List<EffectNode> effects = [];
  String? condition;
  String? label;

  ItemNode(this.span);

  /// The engine `type` this item compiles to.
  String get type;
}

/// A spoken line or chat message (`TEXT`).
class LineItem extends ItemNode {
  final ProfileRef speaker;
  String? position;
  int? typingMs;
  String? sfx;
  String? voice;
  String? delivery;

  LineItem(super.span, this.speaker);

  @override
  String get type => "TEXT";
}

class NarrationItem extends ItemNode {
  /// `null` for plain narration, `system` or `timestamp`.
  final String? style;
  String? sfx;

  NarrationItem(super.span, this.style);

  @override
  String get type => "NARRATION";
}

class MediaItem extends ItemNode {
  final String mediaType;
  final String uri;
  ProfileRef? by;
  String? unlock;
  int? typingMs;
  String? sfx;
  String? delivery;

  MediaItem(super.span, this.mediaType, this.uri);

  bool get isVoiceNote => mediaType == "AUDIO";

  @override
  String get type => "MEDIA";
}

class ChoiceItem extends ItemNode {
  final String? variable;
  ProfileRef? by;
  int? timeoutMs;
  final List<OptionNode> options = [];

  ChoiceItem(super.span, this.variable);

  @override
  String get type => "CHOICE";
}

class OptionNode implements TextHolder {
  @override
  final SourceSpan span;
  @override
  final Map<String, Localized> texts = {};
  @override
  final List<EffectNode> effects = [];
  String? condition;
  bool isDefault = false;
  bool once = false;
  bool memoryMarker = false;
  Object? value;
  bool hasValue = false;
  TargetRef? target;

  OptionNode(this.span);
}

class InputItem extends ItemNode {
  final String variable;
  Localized? defaultValue;
  ProfileRef? by;

  InputItem(super.span, this.variable);

  @override
  String get type => "INPUT";
}

class WaitItem extends ItemNode {
  final int durationMs;

  WaitItem(super.span, this.durationMs);

  @override
  String get type => "WAIT";
}

class BranchRoute {
  final String condition;
  final TargetRef target;
  final SourceSpan span;

  const BranchRoute(this.condition, this.target, this.span);
}

/// A `branch` router.
class BranchItem extends ItemNode {
  final List<BranchRoute> routes = [];
  TargetRef? fallback;

  BranchItem(super.span);

  @override
  String get type => "BRANCH";
}

/// `-> target` (`JUMP`) or `call target` (`CALL`).
class JumpItem extends ItemNode {
  final TargetRef target;
  final bool isCall;

  JumpItem(super.span, this.target, {this.isCall = false});

  @override
  String get type => isCall ? "CALL" : "JUMP";
}

class ReturnItem extends ItemNode {
  ReturnItem(super.span);

  @override
  String get type => "RETURN";
}

/// Effects with nothing shown: a `set` block, or effect lines at column 0.
class SetItem extends ItemNode {
  SetItem(super.span);

  @override
  String get type => "SET";
}

/// One stage action (data schema §4.12). [fields] are the JSON fields after `action`, in output order. A
/// [ProfileRef] value is resolved when compiling: to `<id>:<sprite>`, or to `<id>` when [idOnly].
class StageAction {
  final String action;
  final SourceSpan span;
  final Map<String, Object?> fields = {};
  bool idOnly = false;

  StageAction(this.action, this.span);

  /// How long the action runs, counted like the engine: an explicit `duration_ms`, else 0 with the `none`
  /// transition, 400 for `shake` and `flash`, and 500 otherwise.
  int get durationMs {
    final explicit = fields["duration_ms"];
    if (explicit is int) return explicit;
    if (fields["transition"] == "none") return 0;
    return action == "shake" || action == "flash" ? 400 : 500;
  }
}

class StageItem extends ItemNode {
  int? waitMs;
  final List<StageAction> actions = [];

  StageItem(super.span);

  /// [waitMs], or the longest action.
  int get effectiveWaitMs =>
      waitMs ?? actions.fold(0, (longest, action) => action.durationMs > longest ? action.durationMs : longest);

  @override
  String get type => "STAGE";
}

class EndingItem extends ItemNode {
  static const categories = ["TRUE", "GOOD", "NORMAL", "BAD", "SECRET"];

  final String endingId;
  final String category;

  EndingItem(super.span, this.endingId, this.category);

  @override
  String get type => "ENDING";
}

class SceneNode {
  final SourceSpan span;
  final String mode;
  String? background;
  String? music;
  String? ambience;
  String? textbox;
  String? channel;
  int? day;
  String? time;

  SceneNode(this.span, this.mode);
}

class ConversationNode {
  static const indexKey = "index";

  final String key;
  final SourceSpan span;
  String? conversationId;
  Localized? chapter;
  Localized? title;
  bool checkpoint = false;
  SceneNode? scene;
  final List<ItemNode> items = [];

  ConversationNode(this.key, this.span);

  /// The JSON file this conversation compiles to.
  String get fileName => key == indexKey ? "index.json" : "cvn_$key.json";
}

class ScriptFile {
  final String path;
  final List<ConversationNode> conversations = [];

  ScriptFile(this.path);
}

/// Words that start a statement, so they can't be speaker names. `clue` and `evidence` are reserved for CE-05
/// and CE-06, whose syntax isn't designed yet.
const statementKeywords = {
  "narration", "system", "timestamp", "media", "choice", "input", "wait", "branch", "ending", "call", "return",
  "set", "toggle", "remember", "stage", "clue", "evidence",
};
