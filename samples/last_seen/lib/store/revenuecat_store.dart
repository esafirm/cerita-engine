import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'store.dart';

/// [GameStore] on RevenueCat. The dashboard sells one non-consumable that grants the [entitlement], as a package in
/// the current offering (the Lifetime package if there is one). The public SDK keys come in with `--dart-define`
/// (`REVENUECAT_ANDROID_KEY`, `REVENUECAT_IOS_KEY`), usually from the git-ignored `revenuecat.json`, see the README.
class RevenueCatStore implements GameStore {
  /// The entitlement's identifier in the RevenueCat dashboard. It can't be renamed there, so it keeps the name it
  /// was created with.
  static const entitlement = "complete_content_bonus";

  static const _androidKey = String.fromEnvironment("REVENUECAT_ANDROID_KEY");
  static const _iosKey = String.fromEnvironment("REVENUECAT_IOS_KEY");

  final StreamController<bool> _changes = StreamController.broadcast();

  String get _key {
    if (kIsWeb) return "";
    final key = switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidKey,
      TargetPlatform.iOS => _iosKey,
      _ => "",
    };
    return usable(key, debug: kDebugMode) ? key : "";
  }

  /// Whether [key] can configure the SDK in this build. A Test Store key (`test_…`) works in debug builds only: the
  /// SDK shows an alert and crashes on purpose in any other build that uses one. The Makefile refuses to build those
  /// with it, and this keeps a build made some other way running, with the store off.
  @visibleForTesting
  static bool usable(String key, {required bool debug}) => key.isNotEmpty && (debug || !key.startsWith("test_"));

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
