/// The purchases layer Last Seen talks to: one non-consumable, the full game. RevenueCat implements it in the app
/// ([RevenueCatStore]) and a fake does in tests, so the entitlement logic in [FullGame] never sees the SDK.
abstract class GameStore {
  /// False when this build can't sell anything: no API key for the platform, or the web.
  bool get available;

  /// Connects to the store. Called once, before anything else.
  Future<void> configure();

  /// Whether the player owns the full game, as the store knows it. Throws [StoreException] when it can't tell,
  /// e.g. offline with nothing cached.
  Future<bool> owned();

  /// The full game as it's on sale now, or null when the store has nothing to offer (products not set up).
  /// Throws [StoreException] when the store can't be reached.
  Future<StoreOffer?> offer();

  /// Buys [offer]. Throws [StoreException] when the purchase fails for a reason other than the player
  /// cancelling it.
  Future<PurchaseOutcome> buy(StoreOffer offer);

  /// Asks the store again for what this account owns. Returns whether it owns the full game. Throws
  /// [StoreException] when it can't be reached.
  Future<bool> restore();

  /// Ownership the store learns about on its own: a pending payment that went through, a refund, a purchase
  /// made on another device.
  Stream<bool> get changes;
}

/// The full game's price, ready to show, plus whatever the store needs to buy it.
class StoreOffer {
  final String price;

  /// The store's own handle on the product, e.g. a RevenueCat package. Opaque to everyone else.
  final Object? handle;

  const StoreOffer(this.price, {this.handle});
}

enum PurchaseOutcome {
  /// The full game is owned now.
  purchased,

  /// The player backed out. Nothing to say.
  cancelled,

  /// The store accepted the order but the payment isn't through yet (e.g. cash at a convenience store).
  /// [GameStore.changes] reports it once it is.
  pending,
}

class StoreException implements Exception {
  final String message;

  const StoreException(this.message);

  @override
  String toString() => "StoreException: $message";
}
