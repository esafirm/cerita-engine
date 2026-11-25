import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/material.dart';

import '../ui/retro.dart';
import 'full_game.dart';
import 'store.dart';

/// The full game's store page: what it unlocks, the price, Buy and Restore. Shown over the story when it reaches
/// Day 3 without the purchase, and from the title menu. Calls [onUnlocked] as soon as the game is unlocked, by a
/// purchase, a restore, or a pending payment that goes through while it's open.
class Paywall extends StatefulWidget {
  final FullGame fullGame;

  /// The chapter the story stopped at. Null from the title menu.
  final String? chapter;
  final VoidCallback onUnlocked;
  final VoidCallback onLeave;

  /// True over the story, where leaving goes back to the title screen.
  final bool overStory;

  const Paywall({
    super.key,
    required this.fullGame,
    required this.onUnlocked,
    required this.onLeave,
    this.chapter,
    this.overStory = false,
  });

  @override
  State<Paywall> createState() => _PaywallState();
}

class _PaywallState extends State<Paywall> {
  late Future<StoreOffer?> _offer = widget.fullGame.offer();

  /// Buying or restoring.
  bool _busy = false;
  String? _message;

  /// [Paywall.onUnlocked] has been called.
  bool _done = false;

  FullGame get _fullGame => widget.fullGame;

  @override
  void initState() {
    super.initState();
    _fullGame.addListener(_changed);
    // Unlocked in the meantime, e.g. by a payment that went through.
    if (_fullGame.unlocked) WidgetsBinding.instance.addPostFrameCallback((_) => _changed());
  }

  @override
  void dispose() {
    _fullGame.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (_done || !mounted || !_fullGame.unlocked) return;
    _done = true;
    widget.onUnlocked();
  }

  Future<void> _run(Future<String?> Function() action) async {
    final text = _Text.of(context);
    UiSounds.instance?.confirm();
    setState(() {
      _busy = true;
      _message = null;
    });
    String? message;
    try {
      message = await action();
    } on StoreException catch (error) {
      message = text.failed(error.message);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
  }

  Future<String?> _buy(StoreOffer offer) async {
    final text = _Text.of(context);
    return switch (await _fullGame.buy(offer)) {
      PurchaseOutcome.purchased || PurchaseOutcome.cancelled => null,
      PurchaseOutcome.pending => text.pending,
    };
  }

  Future<String?> _restore() async {
    final text = _Text.of(context);
    return await _fullGame.restore() ? null : text.nothingToRestore;
  }

  void _retry() => setState(() {
    _message = null;
    _offer = _fullGame.offer();
  });

  @override
  Widget build(BuildContext context) {
    final text = _Text.of(context);
    final chapter = widget.chapter;
    return ColoredBox(
      color: Retro.night.withAlpha(widget.overStory ? 235 : 255),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: RetroWindow(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      text.title,
                      textAlign: TextAlign.center,
                      style: Retro.text.copyWith(
                        fontSize: 24,
                        letterSpacing: 3,
                        shadows: const [Shadow(color: Retro.accent, offset: Offset(2, 2))],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (chapter != null) ...[
                      Text(text.stoppedAt(chapter), style: Retro.text.copyWith(color: Retro.accent)),
                      const SizedBox(height: 6),
                    ],
                    Text(text.pitch, style: Retro.text.copyWith(fontSize: 15)),
                    const SizedBox(height: 16),
                    FutureBuilder(future: _offer, builder: (context, snapshot) => _actions(context, snapshot)),
                    if (_message case final message?) ...[
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: Retro.text.copyWith(color: Retro.narration),
                      ),
                    ],
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              UiSounds.instance?.cancel();
                              widget.onLeave();
                            },
                      child: Text(widget.overStory ? text.backToTitle : text.back),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, AsyncSnapshot<StoreOffer?> snapshot) {
    final text = _Text.of(context);
    final status = Retro.text.copyWith(color: Retro.dim, fontSize: 14);
    if (!_fullGame.canBuy) return Text(text.noStore, textAlign: TextAlign.center, style: status);
    if (snapshot.connectionState != ConnectionState.done) {
      return Text(text.checking, textAlign: TextAlign.center, style: status);
    }
    final offer = snapshot.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (snapshot.hasError)
          TextButton(
            onPressed: _retry,
            child: Text(text.offline, textAlign: TextAlign.center),
          )
        else if (offer == null)
          Text(text.notOnSale, textAlign: TextAlign.center, style: status)
        else
          FilledButton(
            onPressed: _busy ? null : () => _run(() => _buy(offer)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: _busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(text.unlock(offer.price)),
            ),
          ),
        const SizedBox(height: 6),
        TextButton(onPressed: _busy ? null : () => _run(_restore), child: Text(text.restore)),
      ],
    );
  }
}

/// The paywall's words, in the player's language.
class _Text {
  final bool en;

  const _Text(this.en);

  factory _Text.of(BuildContext context) => _Text(StoryLanguage.of(context).locale == "en");

  String get title => en ? "FULL GAME" : "GAME LENGKAP";

  String stoppedAt(String chapter) =>
      en ? "$chapter is part of the full game." : "$chapter termasuk dalam game lengkap.";

  String get pitch => en
      ? "The Prologue, Day 1 and Day 2 are free. One purchase opens Day 3 to Day 7, all ten endings, the bonus "
            "wallpapers and alternate app icons. No ads, no subscription."
      : "Prolog, Hari 1 dan Hari 2 gratis. Sekali beli, Hari 3 sampai Hari 7, kesepuluh ending, "
            "wallpaper bonus dan ikon aplikasi alternatif terbuka. Tanpa iklan, tanpa langganan.";

  String unlock(String price) => en ? "UNLOCK · $price" : "BUKA · $price";
  String get restore => en ? "Restore purchase" : "Pulihkan pembelian";
  String get back => en ? "Back" : "Kembali";
  String get backToTitle => en ? "Back to title" : "Kembali ke menu utama";
  String get checking => en ? "Checking the store..." : "Mengecek toko...";
  String get noStore => en ? "The store isn't available in this version." : "Toko tidak tersedia di versi ini.";
  String get notOnSale => en ? "The full game isn't on sale right now." : "Game lengkap belum dijual saat ini.";
  String get offline =>
      en ? "Couldn't reach the store. Tap to try again." : "Tidak bisa menghubungi toko. Ketuk untuk coba lagi.";
  String get pending => en
      ? "Payment pending. The rest of the story opens once it goes through."
      : "Pembayaran tertunda. Sisa cerita terbuka setelah pembayaran masuk.";
  String get nothingToRestore => en ? "No purchase found on this account." : "Tidak ada pembelian di akun ini.";
  String failed(String reason) => en ? "Purchase failed: $reason" : "Pembelian gagal: $reason";
}
