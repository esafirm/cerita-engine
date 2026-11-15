import '../l10n/localized_text.dart';
import 'items/base.dart';
import 'scene.dart';

class Conversation {
  /// Key of the entry-point conversation (`index.json`).
  static const indexKey = "index";

  /// Key used to load this conversation: [indexKey] or the `<id>` of `cvn_<id>.json`.
  final String key;
  final String conversationId;

  /// [chapterText] and [titleText] resolved with the [Localizer] this conversation was read with.
  final String? chapter;
  final String? title;

  /// Chapter and title in every language. Compare these, not [chapter], to tell chapters apart.
  final LocalizedText? chapterText;
  final LocalizedText? titleText;
  final bool checkpoint;
  final Scene scene;

  /// False when the JSON has no `scene`: the conversation continues the current scene and stage,
  /// e.g. a `CALL` subroutine shared by several chapters.
  final bool hasScene;
  final List<ItemType> conversations;

  /// The story's languages. Only declared in `index.json`; defaults elsewhere.
  final StoryLocales locales;

  Conversation({
    required this.key,
    required this.conversationId,
    required this.conversations,
    this.scene = const Scene(),
    this.hasScene = true,
    this.chapterText,
    this.titleText,
    this.checkpoint = false,
    this.locales = const StoryLocales(),
    Localizer localizer = const Localizer(),
  })  : chapter = localizer.maybe(chapterText),
        title = localizer.maybe(titleText);

  factory Conversation.fromJson(Map<String, dynamic> json, {required String key}) {
    final jsonConv = json["conversations"] as List<dynamic>;
    return Conversation(
      key: key,
      conversationId: json["conversation_id"] as String,
      chapterText: LocalizedText.fromJson(json["chapter"]),
      titleText: LocalizedText.fromJson(json["title"]),
      checkpoint: json["checkpoint"] as bool? ?? false,
      scene: Scene.fromJson(json["scene"] as Map<String, dynamic>?),
      hasScene: json["scene"] != null,
      conversations: jsonConv.map((raw) => ItemType.fromJson(Map<String, dynamic>.from(raw as Map))).toList(),
      locales: StoryLocales.fromJson(json),
    );
  }

  /// The same conversation with [chapter] and [title] in [localizer]'s language. Items are localized by
  /// the engine as it delivers them.
  Conversation localized(Localizer localizer) => Conversation(
        key: key,
        conversationId: conversationId,
        conversations: conversations,
        scene: scene,
        hasScene: hasScene,
        chapterText: chapterText,
        titleText: titleText,
        checkpoint: checkpoint,
        locales: locales,
        localizer: localizer,
      );
}
