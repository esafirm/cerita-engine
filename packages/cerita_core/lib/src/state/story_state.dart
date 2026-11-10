import 'dart:collection';

/// The variables expressions see: the playthrough [session] map, plus [persistent] under
/// `persistent.<name>`. Writes go to the map the key belongs to.
class StoryState extends MapBase<String, dynamic> {
  static const persistentPrefix = "persistent.";

  final Map<String, dynamic> session;
  final Map<String, dynamic> Function() _persistent;

  /// Set when a persistent variable is written, so the caller knows to save the meta-state.
  bool persistentDirty = false;

  StoryState(this.session, Map<String, dynamic> Function() persistent) : _persistent = persistent;

  Map<String, dynamic> get persistent => _persistent();

  static bool isPersistent(Object? key) => key is String && key.startsWith(persistentPrefix);

  static String _strip(String key) => key.substring(persistentPrefix.length);

  @override
  dynamic operator [](Object? key) => isPersistent(key) ? persistent[_strip(key as String)] : session[key];

  @override
  void operator []=(String key, dynamic value) {
    if (isPersistent(key)) {
      persistent[_strip(key)] = value;
      persistentDirty = true;
    } else {
      session[key] = value;
    }
  }

  @override
  bool containsKey(Object? key) =>
      isPersistent(key) ? persistent.containsKey(_strip(key as String)) : session.containsKey(key);

  @override
  Iterable<String> get keys => [...session.keys, ...persistent.keys.map((key) => "$persistentPrefix$key")];

  @override
  dynamic remove(Object? key) {
    if (!isPersistent(key)) return session.remove(key);
    persistentDirty = true;
    return persistent.remove(_strip(key as String));
  }

  @override
  void clear() => session.clear();
}
