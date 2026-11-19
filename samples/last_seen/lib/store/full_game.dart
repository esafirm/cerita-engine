import 'dart:async';

import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'store.dart';

/// Whether the player may play past Day 2: the one thing Last Seen sells. The story asks [allows] before every
/// conversation (the engine's story gate), so it applies to new games, saves, the chapter list and the admin
/// sheet's unlocks alike.
///
/// The game is unlocked when the store says the full game is owned, for a tester build, or for a player who had
/// already played past Day 2 before the game was sold (grandfathered, checked once). What the store said last is
/// cached, so an owner can play offline.
class FullGame extends ChangeNotifier {
  /// The free chapters, by their name in the story's source language (Indonesian).
  static const freeChapters = {"Prolog", "Hari 1", "Hari 2"};

  static const _ownedKey = "last_seen.full_game.owned";
  static const _grandfatheredKey = "last_seen.full_game.grandfathered";
  static const _checkedKey = "last_seen.full_game.grandfather_checked";

  final GameStore store;
  final SharedPreferences prefs;

  /// The game's saves and meta-state, read once for the grandfather check.
  final StoryStorage storage;

  /// Plays everything without buying. For playtest builds, never for a store build.
  final bool tester;

  FullGame({required this.store, required this.prefs, required this.storage, this.tester = false});

  bool _owned = false;
  bool _grandfathered = false;
  bool _storeReady = false;
  StreamSubscription<bool>? _changes;

  /// Whether Day 3 onwards can be played.
  bool get unlocked => tester || _owned || _grandfathered;

  /// Whether this build can sell the full game: a store with a key, configured.
  bool get canBuy => _storeReady;

  /// A conversation in a free chapter, or one without a chapter, is always open.
  static bool isFree(LocalizedText? chapter) => chapter == null || freeChapters.contains(chapter.resolve("id"));

  /// The story gate.
  bool allows(Conversation conversation) => unlocked || isFree(conversation.chapterText);

  /// Reads the cache, runs the one-time grandfather check, then connects to the store and asks it in the
  /// background, so the title screen never waits on the network.
  Future<void> load() async {
    _owned = prefs.getBool(_ownedKey) ?? false;
    _grandfathered = prefs.getBool(_grandfatheredKey) ?? false;
    if (!(prefs.getBool(_checkedKey) ?? false)) {
      _grandfathered = await _playedPastFreeChapters();
      await prefs.setBool(_grandfatheredKey, _grandfathered);
      await prefs.setBool(_checkedKey, true);
    }
    if (!store.available) return;
    try {
      await store.configure();
      _storeReady = true;
    } catch (error) {
      debugPrint("Store unavailable: $error");
      return;
    }
    _changes = store.changes.listen(_setOwned);
    unawaited(refresh());
  }

  /// Asks the store again. Keeps the cached answer when it can't be reached.
  Future<void> refresh() async {
    if (!_storeReady) return;
    try {
      await _setOwned(await store.owned());
    } on StoreException catch (error) {
      debugPrint("Couldn't check the purchase: ${error.message}");
    }
  }

  /// The full game's price, or null when there's nothing for sale. Throws [StoreException].
  Future<StoreOffer?> offer() async {
    if (!_storeReady) return null;
    return store.offer();
  }

  /// Throws [StoreException] when the purchase fails.
  Future<PurchaseOutcome> buy(StoreOffer offer) async {
    final outcome = await store.buy(offer);
    if (outcome == PurchaseOutcome.purchased) await _setOwned(true);
    return outcome;
  }

  /// Returns whether the store found the full game on this account. Throws [StoreException].
  Future<bool> restore() async {
    final owned = await store.restore();
    await _setOwned(owned);
    return owned;
  }

  Future<void> _setOwned(bool owned) async {
    if (owned == _owned) return;
    _owned = owned;
    await prefs.setBool(_ownedKey, owned);
    notifyListeners();
  }

  /// Version 1.0.0 had no store and every day was free. A player who already reached Day 3 keeps it: a paid
  /// chapter's checkpoint, or a save in one, counts.
  Future<bool> _playedPastFreeChapters() async {
    final meta = await storage.loadMeta();
    if (meta.unlockedCheckpoints.values.any((checkpoint) => !isFree(checkpoint.chapter))) return true;
    final saves = await storage.listSlots();
    return saves.any((save) => !isFree(save.chapter));
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }
}
