import 'dart:collection';

import '../utils/condition_evaluator.dart';
import 'meta_state.dart';

/// The variables expressions see: the playthrough [session] map, plus the global meta-state's
/// `persistent.<name>` variables and the read-only cross-playthrough memory, `meta.ending.<id>` and
/// `meta.flag.<name>`. Writes go to the map the key belongs to.
class StoryState extends MapBase<String, dynamic> {
  static const persistentPrefix = "persistent.";
  static const metaPrefix = "meta.";
  static const endingPrefix = "meta.ending.";
  static const flagPrefix = "meta.flag.";

  final Map<String, dynamic> session;
  final GlobalMetaState Function() _meta;

  /// Set when a persistent variable is written or a fact is remembered, so the caller knows to save the
  /// meta-state.
  bool persistentDirty = false;

  StoryState(this.session, GlobalMetaState Function() meta) : _meta = meta;

  Map<String, dynamic> get persistent => _meta().persistent;

  static bool isPersistent(Object? key) => key is String && key.startsWith(persistentPrefix);

  /// Whether [key] is a read-only `meta.*` memory variable.
  static bool isMeta(Object? key) => key is String && key.startsWith(metaPrefix);

  static String _strip(String key) => key.substring(persistentPrefix.length);

  /// Remembers [fact] across playthroughs, see the `meta_set` effect op.
  void remember(String fact) {
    if (_meta().rememberedFacts.add(fact)) persistentDirty = true;
  }

  bool _readMeta(String key) {
    String? name(String prefix) =>
        key.startsWith(prefix) && key.length > prefix.length ? key.substring(prefix.length) : null;
    if (name(endingPrefix) case final ending?) return _meta().unlockedEndingIds.contains(ending);
    if (name(flagPrefix) case final fact?) return _meta().rememberedFacts.contains(fact);
    throw ConditionException("Unknown memory variable '$key'. Use meta.ending.<ending_id> or meta.flag.<name>");
  }

  static Never _readOnly(String key) =>
      throw StateError("'$key' is read-only. Remember facts with the meta_set effect op");

  @override
  dynamic operator [](Object? key) {
    if (isMeta(key)) return _readMeta(key as String);
    return isPersistent(key) ? persistent[_strip(key as String)] : session[key];
  }

  @override
  void operator []=(String key, dynamic value) {
    if (isMeta(key)) _readOnly(key);
    if (isPersistent(key)) {
      persistent[_strip(key)] = value;
      persistentDirty = true;
    } else {
      session[key] = value;
    }
  }

  /// `meta.*` variables always have a value, `false` when not remembered.
  @override
  bool containsKey(Object? key) {
    if (isMeta(key)) return true;
    return isPersistent(key) ? persistent.containsKey(_strip(key as String)) : session.containsKey(key);
  }

  @override
  Iterable<String> get keys => [...session.keys, ...persistent.keys.map((key) => "$persistentPrefix$key")];

  @override
  dynamic remove(Object? key) {
    if (isMeta(key)) _readOnly(key as String);
    if (!isPersistent(key)) return session.remove(key);
    persistentDirty = true;
    return persistent.remove(_strip(key as String));
  }

  @override
  void clear() => session.clear();
}
