import 'data/conversation.dart';
import 'data/items/ending.dart';
import 'data/items/media.dart';
import 'loader.dart';

/// Every collectible, ending and checkpoint declared across the story files.
/// Meta-game screens compare it against the unlocked IDs in `GlobalMetaState`.
class StoryCatalog {
  final List<Conversation> conversations;

  const StoryCatalog(this.conversations);

  static Future<StoryCatalog> load(EngineLoader loader) async {
    final keys = await loader.listConversationKeys();
    return StoryCatalog([for (final key in keys) await loader.loadConversation(key)]);
  }

  List<CatalogEntry<MediaItemType>> get media => _collect<MediaItemType>((item) => item.unlockId != null)
      .fold(<String, CatalogEntry<MediaItemType>>{}, (map, entry) => map..putIfAbsent(entry.item.unlockId!, () => entry))
      .values
      .toList();

  List<CatalogEntry<EndingItemType>> get endings => _collect<EndingItemType>((_) => true)
      .fold(<String, CatalogEntry<EndingItemType>>{}, (map, entry) => map..putIfAbsent(entry.item.endingId, () => entry))
      .values
      .toList();

  List<Conversation> get checkpoints => conversations.where((conversation) => conversation.checkpoint).toList()
    ..sort((a, b) => (a.scene.day ?? 0).compareTo(b.scene.day ?? 0));

  Iterable<CatalogEntry<T>> _collect<T>(bool Function(T item) where) sync* {
    for (final conversation in conversations) {
      for (final item in conversation.conversations.whereType<T>()) {
        if (where(item)) yield CatalogEntry(item, conversation);
      }
    }
  }
}

class CatalogEntry<T> {
  final T item;

  /// The conversation that declares [item]. Used for unlock hints like "Unlocked in Day 1".
  final Conversation source;

  const CatalogEntry(this.item, this.source);

  String get hint => "Unlocked in ${source.chapter ?? source.title ?? source.key}";
}
