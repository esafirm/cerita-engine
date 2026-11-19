import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'store.dart';

/// [GameStore] on RevenueCat. The dashboard sells one non-consumable that grants the [entitlement], as a package in
/// the current offering (the Lifetime package if there is one). The public SDK keys come in with `--dart-define`
/// (`REVENUECAT_ANDROID_KEY`, `REVENUECAT_IOS_KEY`), usually from the git-ignored `revenuecat.json`, see the README.
class RevenueCatStore implements GameStore {
  static const entitlement = "full_game";

  static const _androidKey = String.fromEnvironment("REVENUECAT_ANDROID_KEY");
  static const _iosKey = String.fromEnvironment("REVENUECAT_IOS_KEY");

  final StreamController<bool> _changes = StreamController.broadcast();

  String get _key {
    if (kIsWeb) return "";
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidKey,
      TargetPlatform.iOS => _iosKey,
      _ => "",
    };
  }

  @override
  bool get available => _key.isNotEmpty;

  @override
  Stream<bool> get changes => _changes.stream;

  static bool _owns(CustomerInfo info) => info.entitlements.active.containsKey(entitlement);

  @override
  Future<void> configure() async {
    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
    await Purchases.configure(PurchasesConfiguration(_key));
    Purchases.addCustomerInfoUpdateListener((info) => _changes.add(_owns(info)));
  }

  @override
  Future<bool> owned() => _call(() async => _owns(await Purchases.getCustomerInfo()));

  @override
  Future<StoreOffer?> offer() => _call(() async {
        final offering = (await Purchases.getOfferings()).current;
        final package = offering?.lifetime ?? offering?.availablePackages.firstOrNull;
        if (package == null) return null;
        return StoreOffer(package.storeProduct.priceString, handle: package);
      });

  @override
  Future<PurchaseOutcome> buy(StoreOffer offer) async {
    final package = offer.handle;
    if (package is! Package) throw StateError("Not a RevenueCat offer: $offer");
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return _owns(result.customerInfo) ? PurchaseOutcome.purchased : PurchaseOutcome.pending;
    } on PlatformException catch (error) {
      switch (PurchasesErrorHelper.getErrorCode(error)) {
        case PurchasesErrorCode.purchaseCancelledError:
          return PurchaseOutcome.cancelled;
        case PurchasesErrorCode.paymentPendingError:
          return PurchaseOutcome.pending;
        // Bought before, e.g. on another device or before a reinstall.
        case PurchasesErrorCode.productAlreadyPurchasedError:
          return await restore() ? PurchaseOutcome.purchased : throw StoreException(error.message ?? error.code);
        default:
          throw StoreException(error.message ?? error.code);
      }
    }
  }

  @override
  Future<bool> restore() => _call(() async => _owns(await Purchases.restorePurchases()));

  static Future<T> _call<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (error) {
      throw StoreException(error.message ?? error.code);
    }
  }
}
