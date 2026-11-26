import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

import 'store/full_game.dart';
import 'ui/retro.dart';

/// A phone wallpaper in Extras. The art is in `assets/wallpapers/`, its prompt in `art/prompts/<name>.txt`.
class Wallpaper {
  /// The file name without extension, e.g. `wallpaper_seawall`. Also the name it's saved under.
  final String name;
  final String titleId;
  final String titleEn;

  const Wallpaper(this.name, this.titleId, this.titleEn);

  String get asset => "assets/wallpapers/$name.jpg";

  String title(bool en) => en ? titleEn : titleId;
}

/// Bonus wallpapers, part of the full game. The first is the app icon's picture.
const wallpapers = [
  Wallpaper("wallpaper_seawall", "Tanggul", "Seawall"),
  Wallpaper("wallpaper_lookback", "Menoleh", "Looking Back"),
  Wallpaper("wallpaper_undelivered", "Tak Terkirim", "Undelivered"),
  Wallpaper("wallpaper_dawn", "Subuh", "Dawn"),
  Wallpaper("wallpaper_studio", "Studio Kamar", "Bedroom Studio"),
  Wallpaper("wallpaper_awake", "Belum Tidur", "Still Awake"),
  Wallpaper("wallpaper_crossing", "Penyeberangan", "The Crossing"),
  Wallpaper("wallpaper_warung", "Warung Malam", "Night Warung"),
  Wallpaper("wallpaper_rooftop", "Di Atap", "Rooftop"),
  Wallpaper("wallpaper_storm", "Badai", "Storm"),
];

/// Puts an image into the device's photos. Throws [WallpaperSaveException] when it can't.
typedef WallpaperSaver = Future<void> Function(Uint8List bytes, String name);

class WallpaperSaveException implements Exception {
  /// True when the player said no to photo access, so the message can say how to fix it.
  final bool denied;

  /// True on platforms where saving straight to the device gallery isn't supported (e.g. web).
  final bool unsupported;

  const WallpaperSaveException({this.denied = false, this.unsupported = false});
}

Future<void> saveToPhotos(Uint8List bytes, String name) async {
  if (kIsWeb) throw const WallpaperSaveException(unsupported: true);
  try {
    if (!await Gal.hasAccess() && !await Gal.requestAccess()) throw const WallpaperSaveException(denied: true);
    await Gal.putImageBytes(bytes, name: name);
  } on GalException catch (error) {
    throw WallpaperSaveException(denied: error.type == GalExceptionType.accessDenied);
  }
}

/// Extras → Wallpapers: the wallpapers in a grid. Locked ones (the full game not owned) open [onLocked], the
/// paywall. An open one shows full screen with a button to save it to the photos.
class WallpapersScreen extends StatelessWidget {
  final FullGame fullGame;
  final VoidCallback onLocked;
  final WallpaperSaver save;

  const WallpapersScreen({super.key, required this.fullGame, required this.onLocked, this.save = saveToPhotos});

  @override
  Widget build(BuildContext context) {
    final text = _Text.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(text.title)),
      body: ListenableBuilder(
        listenable: fullGame,
        builder: (context, _) => GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 12,
          childAspectRatio: 0.48,
          children: [
            for (final wallpaper in wallpapers)
              _Tile(
                wallpaper: wallpaper,
                locked: !fullGame.unlocked,
                onTap: () {
                  if (!fullGame.unlocked) return onLocked();
                  UiSounds.instance?.confirm();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WallpaperViewer(wallpaper: wallpaper, save: save),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final Wallpaper wallpaper;
  final bool locked;
  final VoidCallback onTap;

  const _Tile({required this.wallpaper, required this.locked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = _Text.of(context);
    return Semantics(
      button: true,
      label: locked ? "${wallpaper.title(text.en)}, ${text.locked}" : wallpaper.title(text.en),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Retro.frame, width: 2),
                  boxShadow: const [Retro.shadow],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(wallpaper.asset, fit: BoxFit.cover, cacheWidth: 360),
                    // Locked: the picture shows through a dark veil, a teaser, with the lock on top.
                    if (locked) ...[
                      ColoredBox(color: Retro.night.withAlpha(190)),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline, color: Retro.frame),
                            const SizedBox(height: 6),
                            Text(text.fullGame, textAlign: TextAlign.center, style: Retro.text.copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              wallpaper.title(text.en),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Retro.text.copyWith(fontSize: 13, color: locked ? Retro.dim : Retro.frame),
            ),
          ],
        ),
      ),
    );
  }
}

/// One wallpaper, whole, over black, with Save and Back in a window at the bottom.
class WallpaperViewer extends StatefulWidget {
  final Wallpaper wallpaper;
  final WallpaperSaver save;

  const WallpaperViewer({super.key, required this.wallpaper, this.save = saveToPhotos});

  @override
  State<WallpaperViewer> createState() => _WallpaperViewerState();
}

class _WallpaperViewerState extends State<WallpaperViewer> {
  bool _busy = false;
  String? _message;

  Future<void> _save() async {
    final text = _Text.of(context);
    UiSounds.instance?.confirm();
    setState(() {
      _busy = true;
      _message = null;
    });
    String message;
    try {
      final data = await rootBundle.load(widget.wallpaper.asset);
      await widget.save(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), widget.wallpaper.name);
      message = text.saved;
    } on WallpaperSaveException catch (error) {
      message = error.unsupported
          ? text.unsupported
          : error.denied
          ? text.denied
          : text.failed;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = _Text.of(context);
    final message = _message;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SafeArea(bottom: false, child: Image.asset(widget.wallpaper.asset, fit: BoxFit.contain)),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: RetroWindow(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.wallpaper.title(text.en).toUpperCase(),
                    textAlign: TextAlign.center,
                    style: Retro.text.copyWith(letterSpacing: 3),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _busy
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(text.save),
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Retro.text.copyWith(color: Retro.narration),
                    ),
                  ],
                  TextButton(
                    onPressed: () {
                      UiSounds.instance?.cancel();
                      Navigator.of(context).pop();
                    },
                    child: Text(text.back),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The wallpaper screens' words, in the player's language.
class _Text {
  final bool en;

  const _Text(this.en);

  factory _Text.of(BuildContext context) => _Text(StoryLanguage.of(context).locale == "en");

  String get title => en ? "Wallpapers" : "Wallpaper";
  String get locked => en ? "locked, part of the full game" : "terkunci, bagian dari game lengkap";
  String get fullGame => en ? "Full game" : "Game lengkap";
  String get save => en ? "SAVE TO PHOTOS" : "SIMPAN KE GALERI";
  String get saved =>
      en ? "Saved. Set it as your wallpaper from your photos." : "Tersimpan. Pasang sebagai wallpaper dari galeri.";
  String get denied => en
      ? "No access to your photos. Allow it in the phone's settings."
      : "Tidak ada akses ke galeri. Izinkan di pengaturan HP.";
  String get unsupported =>
      en ? "Saving to photos is only available in the mobile app." : "Simpan ke galeri hanya tersedia di aplikasi HP.";
  String get failed => en ? "Couldn't save the wallpaper." : "Gagal menyimpan wallpaper.";
  String get back => en ? "Back" : "Kembali";
}
