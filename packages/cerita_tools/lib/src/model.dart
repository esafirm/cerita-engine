import 'diagnostics.dart';

/// Text written per locale. With one locale it compiles to a plain string, otherwise to `{locale: text}` (CE-01).
class Localized {
  final SourceSpan span;
  final Map<String, String> values = {};
  final Map<String, SourceSpan> spans = {};

  /// A plain YAML value (a name or handle in profiles.yaml): the same in every locale, so it stays a plain string
  /// and isn't checked for translations.
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

/// A file named once for every locale (`voice=x.mp3`), per locale (`voice.en=x.en.mp3`) or with a `{locale}`
/// template (`voice=x.{locale}.mp3`).
class LocalizedAsset {
  static const placeholder = "{locale}";

  final SourceSpan span;
  String? shared;
  final Map<String, String> perLocale = {};

  LocalizedAsset(this.span, [this.shared]);

  bool get isTemplate => shared?.contains(placeholder) ?? false;

  bool get isPerLocale => isTemplate || perLocale.isNotEmpty;

  /// The file for each of [locales] that has one. A shared, non-template file is listed under [source] only.
  Map<String, String> resolve(List<String> locales, String source) {
    final result = <String, String>{};
    for (final locale in locales) {
      final file = perLocale[locale] ??
          (isTemplate ? shared!.replaceAll(placeholder, locale) : (locale == source ? shared : null));
      if (file != null) result[locale] = file;
    }
    return result;
  }

  /// Every concrete file this refers to, for asset checks.
  Iterable<String> files(List<String> locales, String source) {
    final resolved = resolve(locales, source).values.toSet();
    if (!isTemplate && shared != null) resolved.add(shared!);
    return resolved;
  }
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

class TargetRef {
  final String key;
  final SourceSpan span;

  const TargetRef(this.key, this.span);
}

class EffectNode {
  static const metaSet = "meta_set";

  final String variable;
  final String op;
  final Object? value;
  final bool hasValue;
  final SourceSpan span;

  const EffectNode(this.variable, this.op, this.span, {this.value, this.hasValue = false});

  bool get isRemember => op == metaSet;
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
  LocalizedAsset? voice;
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
  final LocalizedAsset uri;
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

/// A `branch` router, or a `-> key` jump (a branch with only a fallback).
class BranchItem extends ItemNode {
  final List<BranchRoute> routes = [];
  TargetRef? fallback;

  BranchItem(super.span);

  @override
  String get type => "BRANCH";
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
  "narration", "system", "timestamp", "media", "choice", "input", "wait", "branch", "ending", //
  "clue", "evidence",
};
