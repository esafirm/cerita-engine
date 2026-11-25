import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'store/full_game.dart';
import 'ui/retro.dart';

/// An app icon players can pick in Extras. The art is `art/icon/icon_<name>.png` (the main one `art/icon/icon.png`),
/// drawn from `art/prompts/icon_<name>.txt`, and `tools/make-icon.sh` writes the launcher icons and the preview.
class AppIcon {
  /// What Android's MainActivity and iOS's AppDelegate call it, and the preview's file name.
  final String name;
  final String titleId;
  final String titleEn;

  const AppIcon(this.name, this.titleId, this.titleEn);

  String get preview => "assets/icons/$name.png";

  String title(bool en) => en ? titleEn : titleId;
}

/// The main icon first, free. The others are part of the full game, like the wallpapers they share a picture with.
const appIcons = [
  AppIcon("seawall", "Tanggul", "Seawall"),
  AppIcon("lookback", "Menoleh", "Looking Back"),
  AppIcon("undelivered", "Tak Terkirim", "Undelivered"),
];

/// Switches the launcher icon. On Android each icon is a launcher entry in the manifest and MainActivity turns the
/// picked one on once the player leaves the game, since Android closes the game when the entry it was opened through
/// goes off. On iOS each is an alternate icon set in Assets.xcassets and AppDelegate switches it at once, with a
/// system alert.
class AppIconSwitch {
  static const _channel = MethodChannel("seawall/app_icon");

  const AppIconSwitch();

  bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// The [AppIcon.name] in use, or on Android picked and waiting for the player to leave the game.
  Future<String> current() async => await _channel.invokeMethod<String>("current") ?? appIcons.first.name;

  Future<void> set(String name) => _channel.invokeMethod<void>("set", name);
}

/// Extras → App icon: the icons in a row, the one in use marked. Locked ones (the full game not owned) open
/// [onLocked], the paywall.
class AppIconsScreen extends StatefulWidget {
  final FullGame fullGame;
  final VoidCallback onLocked;
  final AppIconSwitch icons;

  const AppIconsScreen({super.key, required this.fullGame, required this.onLocked, this.icons = const AppIconSwitch()});

  @override
  State<AppIconsScreen> createState() => _AppIconsScreenState();
}

class _AppIconsScreenState extends State<AppIconsScreen> {
  String? _current;
  String? _message;

  @override
  void initState() {
    super.initState();
    widget.icons.current().then((name) {
      if (mounted) setState(() => _current = name);
    }, onError: (Object _) {});
  }

  bool _locked(AppIcon icon) => icon != appIcons.first && !widget.fullGame.unlocked;

  Future<void> _pick(AppIcon icon) async {
    if (_locked(icon)) return widget.onLocked();
    if (icon.name == _current) return;
    final text = _Text.of(context);
    UiSounds.instance?.confirm();
    String message;
    try {
      await widget.icons.set(icon.name);
      _current = icon.name;
      message = defaultTargetPlatform == TargetPlatform.iOS ? text.changedNow : text.changed;
    } on PlatformException {
      message = text.failed;
    }
    if (mounted) setState(() => _message = message);
  }

  @override
  Widget build(BuildContext context) {
    final text = _Text.of(context);
    final message = _message;
    return Scaffold(
      appBar: AppBar(title: Text(text.title)),
      body: ListenableBuilder(
        listenable: widget.fullGame,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(text.intro, style: Retro.text.copyWith(color: Retro.narration)),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final icon in appIcons)
                  Expanded(
                    child: _Tile(
                      icon: icon,
                      locked: _locked(icon),
                      selected: icon.name == _current,
                      onTap: () => _pick(icon),
                    ),
                  ),
              ],
            ),
            if (message != null) ...[
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Retro.text.copyWith(color: Retro.narration),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final AppIcon icon;
  final bool locked;
  final bool selected;
  final VoidCallback onTap;

  const _Tile({required this.icon, required this.locked, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = _Text.of(context);
    final title = icon.title(text.en);
    return Semantics(
      button: true,
      selected: selected,
      label: [title, if (selected) text.inUse, if (locked) text.locked].join(", "),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              // The ring marks the icon in use, the way launchers round icons off.
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? Retro.frame : Colors.transparent, width: 3),
                ),
                child: ClipOval(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(icon.preview, fit: BoxFit.cover),
                        if (locked) ...[
                          ColoredBox(color: Retro.night.withAlpha(190)),
                          const Icon(Icons.lock_outline, color: Retro.frame),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: Retro.text.copyWith(fontSize: 13, color: locked ? Retro.dim : Retro.frame),
              ),
              Text(
                selected
                    ? text.inUse
                    : locked
                    ? text.fullGame
                    : "",
                textAlign: TextAlign.center,
                style: Retro.text.copyWith(fontSize: 11, color: Retro.dim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The app icon screen's words, in the player's language.
class _Text {
  final bool en;

  const _Text(this.en);

  factory _Text.of(BuildContext context) => _Text(StoryLanguage.of(context).locale == "en");

  String get title => en ? "App icon" : "Ikon aplikasi";
  String get intro =>
      en ? "Pick the icon Seawall wears on your home screen." : "Pilih ikon Seawall di layar utama HP-mu.";
  String get inUse => en ? "In use" : "Dipakai";
  String get locked => en ? "locked, part of the full game" : "terkunci, bagian dari game lengkap";
  String get fullGame => en ? "Full game" : "Game lengkap";
  String get changed => en
      ? "Done. The new icon shows on your home screen once you leave the game."
      : "Beres. Ikon baru muncul di layar utama setelah kamu keluar dari game.";
  String get changedNow =>
      en ? "Done. The new icon is on your home screen." : "Beres. Ikon baru sudah ada di layar utama.";
  String get failed => en ? "Couldn't change the icon." : "Gagal mengganti ikon.";
}
