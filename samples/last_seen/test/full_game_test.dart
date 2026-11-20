import 'dart:async';

import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_seen/store/full_game.dart';
import 'package:last_seen/store/paywall.dart';
import 'package:last_seen/store/revenuecat_store.dart';
import 'package:last_seen/store/store.dart';
import 'package:last_seen/wallpapers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The purchases layer, scripted. [owns] is what the store reports, and an unreachable store throws on every call.
class _FakeStore implements GameStore {
  @override
  bool available;
  bool reachable;
  bool owns;
  StoreOffer? onSale;
  PurchaseOutcome outcome;
  final StreamController<bool> _changes = StreamController.broadcast();
  int purchases = 0;

  _FakeStore({
    this.available = true,
    this.reachable = true,
    this.owns = false,
    this.onSale = const StoreOffer("Rp 49.000"),
    this.outcome = PurchaseOutcome.purchased,
  });

  void _reach() {
    if (!reachable) throw const StoreException("offline");
  }

  /// The store finds out by itself, e.g. a pending payment went through or a refund.
  void report(bool owns) {
    this.owns = owns;
    _changes.add(owns);
  }

  @override
  Stream<bool> get changes => _changes.stream;

  @override
  Future<void> configure() async {}

  @override
  Future<bool> owned() async {
    _reach();
    return owns;
  }

  @override
  Future<StoreOffer?> offer() async {
    _reach();
    return onSale;
  }

  @override
  Future<PurchaseOutcome> buy(StoreOffer offer) async {
    _reach();
    purchases++;
    if (outcome == PurchaseOutcome.purchased) owns = true;
    return outcome;
  }

  @override
  Future<bool> restore() async {
    _reach();
    return owns;
  }
}

Conversation _conversation(String key, String? chapter) => Conversation(
  key: key,
  conversationId: key,
  conversations: const [],
  chapterText: chapter == null ? null : LocalizedText.fromJson({"id": chapter, "en": "?"}),
);

final _day2 = _conversation("d2_morning", "Hari 2");
final _day3 = _conversation("d3_angke", "Hari 3");

Checkpoint _checkpoint(String key, String chapter) => Checkpoint(
  conversationKey: key,
  chapter: LocalizedText.fromJson({"id": chapter, "en": "?"}),
  dataMap: const {},
  unlockedAt: DateTime(2026),
);

/// A FullGame on a fresh install (or on [storage], the progress an older version left), loaded.
Future<FullGame> _load(_FakeStore store, {StoryStorage? storage, bool tester = false}) async {
  final fullGame = FullGame(
    store: store,
    prefs: await SharedPreferences.getInstance(),
    storage: storage ?? InMemoryStoryStorage(),
    tester: tester,
  );
  await fullGame.load();
  // The store is asked in the background.
  await pumpEventQueue();
  return fullGame;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the gate', () {
    test('a new player gets the Prologue to Day 2, then needs the full game', () async {
      final fullGame = await _load(_FakeStore());
      expect(fullGame.unlocked, isFalse);
      for (final chapter in ["Prolog", "Hari 1", "Hari 2"]) {
        expect(fullGame.allows(_conversation("free", chapter)), isTrue, reason: chapter);
      }
      for (final chapter in ["Hari 3", "Hari 5", "Hari 7"]) {
        expect(fullGame.allows(_conversation("paid", chapter)), isFalse, reason: chapter);
      }
      expect(fullGame.allows(_conversation("shared_call", null)), isTrue, reason: "no chapter, not a chapter to sell");
    });

    test('an owner plays everything', () async {
      final fullGame = await _load(_FakeStore(owns: true));
      expect(fullGame.unlocked, isTrue);
      expect(fullGame.allows(_day3), isTrue);
    });

    test('a tester build plays everything without a store', () async {
      final fullGame = await _load(_FakeStore(available: false), tester: true);
      expect(fullGame.allows(_day3), isTrue);
      expect(fullGame.canBuy, isFalse);
    });

    test('the admin sheet\'s unlocked chapters stay closed without the purchase', () async {
      final storage = InMemoryStoryStorage();
      await _load(_FakeStore(), storage: storage);
      // What "Unlock everything" writes, after the one-time check has run.
      final meta = await storage.loadMeta();
      meta.unlockedCheckpoints["d5_morning"] = _checkpoint("d5_morning", "Hari 5");
      await storage.saveMeta(meta);

      final relaunched = await _load(_FakeStore(), storage: storage);
      expect(relaunched.unlocked, isFalse);
      expect(relaunched.allows(_conversation("d5_morning", "Hari 5")), isFalse);
    });
  });

  group('buying', () {
    test('a purchase unlocks the game, tells listeners, and is remembered offline', () async {
      final store = _FakeStore();
      final fullGame = await _load(store);
      var told = 0;
      fullGame.addListener(() => told++);

      expect(await fullGame.buy((await fullGame.offer())!), PurchaseOutcome.purchased);
      expect(fullGame.unlocked, isTrue);
      expect(told, 1);

      final offline = await _load(_FakeStore(reachable: false));
      expect(offline.unlocked, isTrue, reason: "the last answer is cached");
    });

    test('a cancelled purchase changes nothing', () async {
      final fullGame = await _load(_FakeStore(outcome: PurchaseOutcome.cancelled));
      expect(await fullGame.buy((await fullGame.offer())!), PurchaseOutcome.cancelled);
      expect(fullGame.unlocked, isFalse);
    });

    test('a pending payment unlocks once the store reports it', () async {
      final store = _FakeStore(outcome: PurchaseOutcome.pending);
      final fullGame = await _load(store);
      expect(await fullGame.buy((await fullGame.offer())!), PurchaseOutcome.pending);
      expect(fullGame.unlocked, isFalse);

      store.report(true);
      await pumpEventQueue();
      expect(fullGame.unlocked, isTrue);
    });

    test('a failed purchase throws and stays locked', () async {
      final store = _FakeStore();
      final fullGame = await _load(store);
      final offer = (await fullGame.offer())!;
      store.reachable = false;
      await expectLater(fullGame.buy(offer), throwsA(isA<StoreException>()));
      expect(fullGame.unlocked, isFalse);
    });

    test('restore finds an earlier purchase, or says there is none', () async {
      final store = _FakeStore();
      final fullGame = await _load(store);
      expect(await fullGame.restore(), isFalse);
      expect(fullGame.unlocked, isFalse);

      store.owns = true;
      expect(await fullGame.restore(), isTrue);
      expect(fullGame.unlocked, isTrue);
    });

    test('a refund the store reports closes the game again', () async {
      SharedPreferences.setMockInitialValues({"last_seen.full_game.owned": true});
      final store = _FakeStore(owns: false);
      final fullGame = await _load(store);
      expect(fullGame.unlocked, isFalse, reason: "the store's answer replaces the cache");
    });

    test('without a store there is nothing to buy', () async {
      final fullGame = await _load(_FakeStore(available: false));
      expect(fullGame.canBuy, isFalse);
      expect(await fullGame.offer(), isNull);
    });
  });

  group('players from before the store', () {
    test('a player who already reached Day 3 keeps the full game', () async {
      final storage = InMemoryStoryStorage();
      final meta = GlobalMetaState()..unlockedCheckpoints["d3_angke"] = _checkpoint("d3_angke", "Hari 3");
      await storage.saveMeta(meta);
      final fullGame = await _load(_FakeStore(available: false), storage: storage);
      expect(fullGame.unlocked, isTrue);
    });

    test('a player who stopped before Day 3 doesn\'t', () async {
      final storage = InMemoryStoryStorage();
      final meta = GlobalMetaState()..unlockedCheckpoints["d2_morning"] = _checkpoint("d2_morning", "Hari 2");
      await storage.saveMeta(meta);
      final fullGame = await _load(_FakeStore(), storage: storage);
      expect(fullGame.unlocked, isFalse);
      expect(fullGame.allows(_day2), isTrue);
    });
  });

  group('the paywall', () {
    Future<FullGame> pump(WidgetTester tester, _FakeStore store, {required VoidCallback onUnlocked}) async {
      final fullGame = await tester.runAsync(() => _load(store));
      await tester.pumpWidget(
        MaterialApp(
          home: StoryLanguageScope(
            language: StoryLanguage(),
            child: Scaffold(
              body: Paywall(fullGame: fullGame!, chapter: "Day 3", onUnlocked: onUnlocked, onLeave: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return fullGame;
    }

    testWidgets('shows the price and unlocks on purchase', (tester) async {
      var unlocked = 0;
      final store = _FakeStore();
      await pump(tester, store, onUnlocked: () => unlocked++);
      expect(find.textContaining("Rp 49.000"), findsOneWidget);

      await tester.tap(find.textContaining("Rp 49.000"));
      await tester.pumpAndSettle();
      expect(store.purchases, 1);
      expect(unlocked, 1);
    });

    testWidgets('says when a payment is pending', (tester) async {
      var unlocked = 0;
      await pump(tester, _FakeStore(outcome: PurchaseOutcome.pending), onUnlocked: () => unlocked++);
      await tester.tap(find.textContaining("Rp 49.000"));
      await tester.pumpAndSettle();
      expect(find.textContaining("tertunda"), findsOneWidget);
      expect(unlocked, 0);
    });

    testWidgets('says when the store has nothing on sale', (tester) async {
      await pump(tester, _FakeStore(onSale: null), onUnlocked: () {});
      expect(find.text("Game lengkap belum dijual saat ini."), findsOneWidget);
      expect(find.text("Pulihkan pembelian"), findsOneWidget, reason: "restore still works");
    });

    testWidgets('says when this build has no store', (tester) async {
      await pump(tester, _FakeStore(available: false), onUnlocked: () {});
      expect(find.text("Toko tidak tersedia di versi ini."), findsOneWidget);
      expect(find.textContaining("Rp"), findsNothing);
    });
  });

  group('store keys', () {
    test('a production key works in every build', () {
      expect(RevenueCatStore.usable("goog_abc", debug: false), isTrue);
      expect(RevenueCatStore.usable("goog_abc", debug: true), isTrue);
    });

    test('a Test Store key works in debug builds only, the SDK crashes any other build that uses one', () {
      expect(RevenueCatStore.usable("test_abc", debug: true), isTrue);
      expect(RevenueCatStore.usable("test_abc", debug: false), isFalse);
    });

    test('no key, no store', () {
      expect(RevenueCatStore.usable("", debug: true), isFalse);
    });
  });

  group('wallpapers', () {
    Future<void> pump(WidgetTester tester, {required bool owned, VoidCallback? onLocked, WallpaperSaver? save}) async {
      final fullGame = await tester.runAsync(() => _load(_FakeStore(owns: owned)));
      await tester.pumpWidget(
        MaterialApp(
          home: StoryLanguageScope(
            language: StoryLanguage(),
            child: WallpapersScreen(
              fullGame: fullGame!,
              onLocked: onLocked ?? () {},
              save: save ?? (bytes, name) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('are part of the full game: a locked one opens the paywall', (tester) async {
      var paywall = 0;
      await pump(tester, owned: false, onLocked: () => paywall++);
      expect(find.text("Game lengkap"), findsNWidgets(wallpapers.length));

      await tester.tap(find.text("Tanggul"));
      await tester.pumpAndSettle();
      expect(paywall, 1);
      expect(find.byType(WallpaperViewer), findsNothing);
    });

    testWidgets('an owner opens one and saves it to the photos', (tester) async {
      final saved = <String, int>{};
      await pump(tester, owned: true, save: (bytes, name) async => saved[name] = bytes.length);
      expect(find.text("Game lengkap"), findsNothing);

      await tester.tap(find.text("Menoleh"));
      await tester.pumpAndSettle();
      expect(find.byType(WallpaperViewer), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text("SIMPAN KE GALERI"));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(saved.keys, ["wallpaper_lookback"]);
      expect(saved["wallpaper_lookback"], greaterThan(10000));
      expect(find.textContaining("Tersimpan."), findsOneWidget);
    });

    testWidgets('says how to fix it when photo access is denied', (tester) async {
      await pump(tester, owned: true, save: (bytes, name) async => throw const WallpaperSaveException(denied: true));
      await tester.tap(find.text("Tak Terkirim"));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text("SIMPAN KE GALERI"));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(find.textContaining("Izinkan di pengaturan HP"), findsOneWidget);
    });
  });
}
