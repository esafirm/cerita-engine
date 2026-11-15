import 'package:cerita_core/cerita_core.dart';

/// Text the engine shows itself: menus, HUD, toasts, dialogs and meta screens. Story text comes from the
/// story. Built in: [en] and [id]. Subclass it to add a language and pass it to `StoryLanguage(strings:)`.
abstract class CeritaStrings {
  const CeritaStrings();

  static const CeritaStrings en = EnglishCeritaStrings();
  static const CeritaStrings id = IndonesianCeritaStrings();

  static const builtIn = {"en": en, "id": id};

  /// The language's own name, for the language picker.
  String get languageName;

  // Title screen, for apps that want it.
  String get newGame;
  String get continueGame;
  String get load;

  // In-game menu and dialogs.
  String get saveGame;
  String get loadGame;
  String get backlog;
  String get storyVariables;
  String get noVariables;
  String get gallery;
  String get endings;
  String get chapters;
  String get language;
  String get backToTitle;
  String loadError(Object error);

  // HUD. Keep these short: they share one row with the chapter label.
  String get log;
  String get auto;
  String get skip;
  String get menu;

  // Toasts.
  String savedToSlot(int slot);
  String galleryUnlocked(String name);
  String get newGalleryItem;
  String checkpoint(String chapter);

  // Chat and call.
  String get typing;
  String day(int day);
  String get chat;
  String get profile;
  String get messageHint;
  String get calling;
  String get unknownCaller;

  /// The player's name until the story sets `NAME`.
  String get you;

  // Prompts and media.
  String get typeHere;
  String get showTranscript;
  String get hideTranscript;
  String get video;

  // Endings.
  String get theEnd;
  String get allEndings;
  String endingBadge(EndingCategory category);
  String endingsProgress(int unlocked, int total);
  String get lockedEnding;

  // Save slots and chapters.
  String get autosave;
  String slot(int id);
  String get emptySlot;
  String get notReachedYet;

  // Quick save, rollback and replay.
  String get quickSave;
  String get quickLoad;

  /// Short forms for the VN HUD.
  String get quickSaveShort;
  String get quickLoadShort;
  String get quickSaved;
  String get quickLoaded;
  String get noQuickSave;
  String get back;
  String get hide;
  String get playVoice;
  String get rollbackToLine;
  String get replayChapter;
  String get endOfReplay;

  /// Screen-reader label of the marker on choices unlocked by past runs.
  String get memoryMarker;

  // Developer panel entry and its toast. The panel itself is a writing tool and stays English.
  String get developer;
  String get storyReloaded;

  // Settings.
  String get settings;
  String get reset;
  String get text;
  String get preview;

  /// The sample line that shows the text speed.
  String get textPreview;
  String get textSpeed;

  /// Names of `SettingsScreen.textSpeeds`, slowest first.
  List<String> get textSpeeds;
  String get autoForwardDelay;
  String get skipUnread;
  String get skipUnreadHint;
  String get sound;
  String get music;
  String get soundEffects;
  String get voice;
  String get characterVoices;

  // Music room.
  String get musicRoom;
  String get noMusic;
  String tracksHeard(int heard, int total);
  String track(int number);
  String get notHeardYet;

  // Gallery.
  String get photosAndCgs;
  String get voiceNotes;
  String get videos;
  String galleryProgress(int unlocked, int total);
  String unlockedIn(String chapter);
}

class EnglishCeritaStrings extends CeritaStrings {
  const EnglishCeritaStrings();

  @override
  String get languageName => "English";
  @override
  String get newGame => "New game";
  @override
  String get continueGame => "Continue";
  @override
  String get load => "Load";
  @override
  String get saveGame => "Save game";
  @override
  String get loadGame => "Load game";
  @override
  String get backlog => "Backlog";
  @override
  String get storyVariables => "Story variables";
  @override
  String get noVariables => "No variables yet.";
  @override
  String get gallery => "Gallery";
  @override
  String get endings => "Endings";
  @override
  String get chapters => "Chapters";
  @override
  String get language => "Language";
  @override
  String get backToTitle => "Back to title";
  @override
  String loadError(Object error) => "Can't load the story:\n$error";
  @override
  String get log => "Log";
  @override
  String get auto => "Auto";
  @override
  String get skip => "Skip";
  @override
  String get menu => "Menu";
  @override
  String savedToSlot(int slot) => "Saved to slot $slot";
  @override
  String galleryUnlocked(String name) => "Gallery unlocked: $name";
  @override
  String get newGalleryItem => "new item";
  @override
  String checkpoint(String chapter) => "Checkpoint: $chapter";
  @override
  String get typing => "typing…";
  @override
  String day(int day) => "Day $day";
  @override
  String get chat => "Chat";
  @override
  String get profile => "Profile";
  @override
  String get messageHint => "Message";
  @override
  String get calling => "Calling…";
  @override
  String get unknownCaller => "Unknown";
  @override
  String get you => "You";
  @override
  String get typeHere => "Type here";
  @override
  String get showTranscript => "Show transcript";
  @override
  String get hideTranscript => "Hide transcript";
  @override
  String get video => "Video";
  @override
  String get theEnd => "The End";
  @override
  String get allEndings => "All endings";
  @override
  String endingBadge(EndingCategory category) => "${category.key} ENDING";
  @override
  String endingsProgress(int unlocked, int total) => "$unlocked / $total endings";
  @override
  String get lockedEnding => "??? — keep playing to discover this ending";
  @override
  String get autosave => "Autosave";
  @override
  String slot(int id) => "Slot $id";
  @override
  String get emptySlot => "Empty";
  @override
  String get notReachedYet => "Not reached yet";
  @override
  String get photosAndCgs => "Photos & CGs";
  @override
  String get voiceNotes => "Voice notes";
  @override
  String get videos => "Videos";
  @override
  String galleryProgress(int unlocked, int total) => "$unlocked / $total unlocked";
  @override
  String unlockedIn(String chapter) => "Unlocked in $chapter";
  @override
  String get quickSave => "Quick save";
  @override
  String get quickLoad => "Quick load";
  @override
  String get quickSaveShort => "Q.Save";
  @override
  String get quickLoadShort => "Q.Load";
  @override
  String get quickSaved => "Quick saved";
  @override
  String get quickLoaded => "Quick loaded";
  @override
  String get noQuickSave => "No quick save yet";
  @override
  String get back => "Back";
  @override
  String get hide => "Hide";
  @override
  String get playVoice => "Play voice";
  @override
  String get rollbackToLine => "Go back to this line";
  @override
  String get replayChapter => "Replay this chapter";
  @override
  String get endOfReplay => "End of replay";
  @override
  String get memoryMarker => "Unlocked by a past run";
  @override
  String get developer => "Developer";
  @override
  String get storyReloaded => "Story reloaded";
  @override
  String get settings => "Settings";
  @override
  String get reset => "Reset";
  @override
  String get text => "Text";
  @override
  String get preview => "Preview";
  @override
  String get textPreview => "The phone buzzes again. This time, you read the message.";
  @override
  String get textSpeed => "Text speed";
  @override
  List<String> get textSpeeds => const ["Slowest", "Slow", "Normal", "Fast", "Faster", "Instant"];
  @override
  String get autoForwardDelay => "Auto-forward delay";
  @override
  String get skipUnread => "Skip unread text";
  @override
  String get skipUnreadHint => "Skip also fast-forwards lines you haven't read yet.";
  @override
  String get sound => "Sound";
  @override
  String get music => "Music";
  @override
  String get soundEffects => "Sound effects";
  @override
  String get voice => "Voice";
  @override
  String get characterVoices => "Character voices";
  @override
  String get musicRoom => "Music room";
  @override
  String get noMusic => "This story has no music.";
  @override
  String tracksHeard(int heard, int total) => "$heard / $total tracks heard";
  @override
  String track(int number) => "Track $number";
  @override
  String get notHeardYet => "Not heard yet";
}

class IndonesianCeritaStrings extends CeritaStrings {
  const IndonesianCeritaStrings();

  @override
  String get languageName => "Bahasa Indonesia";
  @override
  String get newGame => "Main baru";
  @override
  String get continueGame => "Lanjutkan";
  @override
  String get load => "Muat";
  @override
  String get saveGame => "Simpan permainan";
  @override
  String get loadGame => "Muat permainan";
  @override
  String get backlog => "Riwayat";
  @override
  String get storyVariables => "Variabel cerita";
  @override
  String get noVariables => "Belum ada variabel.";
  @override
  String get gallery => "Galeri";
  @override
  String get endings => "Ending";
  @override
  String get chapters => "Bab";
  @override
  String get language => "Bahasa";
  @override
  String get backToTitle => "Kembali ke menu utama";
  @override
  String loadError(Object error) => "Cerita tidak bisa dimuat:\n$error";
  @override
  String get log => "Log";
  @override
  String get auto => "Auto";
  @override
  String get skip => "Lewati";
  @override
  String get menu => "Menu";
  @override
  String savedToSlot(int slot) => "Tersimpan di slot $slot";
  @override
  String galleryUnlocked(String name) => "Galeri terbuka: $name";
  @override
  String get newGalleryItem => "item baru";
  @override
  String checkpoint(String chapter) => "Checkpoint: $chapter";
  @override
  String get typing => "mengetik…";
  @override
  String day(int day) => "Hari $day";
  @override
  String get chat => "Chat";
  @override
  String get profile => "Profil";
  @override
  String get messageHint => "Pesan";
  @override
  String get calling => "Memanggil…";
  @override
  String get unknownCaller => "Tidak dikenal";
  @override
  String get you => "Kamu";
  @override
  String get typeHere => "Ketik di sini";
  @override
  String get showTranscript => "Tampilkan transkrip";
  @override
  String get hideTranscript => "Sembunyikan transkrip";
  @override
  String get video => "Video";
  @override
  String get theEnd => "Tamat";
  @override
  String get allEndings => "Semua ending";
  @override
  String endingBadge(EndingCategory category) => "ENDING ${switch (category) {
        EndingCategory.trueEnding => "SEJATI",
        EndingCategory.good => "BAIK",
        EndingCategory.normal => "BIASA",
        EndingCategory.bad => "BURUK",
        EndingCategory.secret => "RAHASIA",
      }}";
  @override
  String endingsProgress(int unlocked, int total) => "$unlocked / $total ending";
  @override
  String get lockedEnding => "??? — terus main untuk menemukan ending ini";
  @override
  String get autosave => "Simpan otomatis";
  @override
  String slot(int id) => "Slot $id";
  @override
  String get emptySlot => "Kosong";
  @override
  String get notReachedYet => "Belum tercapai";
  @override
  String get photosAndCgs => "Foto & CG";
  @override
  String get voiceNotes => "Pesan suara";
  @override
  String get videos => "Video";
  @override
  String galleryProgress(int unlocked, int total) => "$unlocked / $total terbuka";
  @override
  String unlockedIn(String chapter) => "Terbuka di $chapter";
  @override
  String get quickSave => "Simpan cepat";
  @override
  String get quickLoad => "Muat cepat";
  @override
  String get quickSaveShort => "Q.Simpan";
  @override
  String get quickLoadShort => "Q.Muat";
  @override
  String get quickSaved => "Tersimpan cepat";
  @override
  String get quickLoaded => "Simpanan cepat dimuat";
  @override
  String get noQuickSave => "Belum ada simpanan cepat";
  @override
  String get back => "Kembali";
  @override
  String get hide => "Sembunyi";
  @override
  String get playVoice => "Putar suara";
  @override
  String get rollbackToLine => "Kembali ke baris ini";
  @override
  String get replayChapter => "Mainkan ulang bab ini";
  @override
  String get endOfReplay => "Akhir putar ulang";
  @override
  String get memoryMarker => "Terbuka dari permainan sebelumnya";
  @override
  String get developer => "Developer";
  @override
  String get storyReloaded => "Cerita dimuat ulang";
  @override
  String get settings => "Pengaturan";
  @override
  String get reset => "Atur ulang";
  @override
  String get text => "Teks";
  @override
  String get preview => "Pratinjau";
  @override
  String get textPreview => "Ponselmu bergetar lagi. Kali ini, kamu membaca pesannya.";
  @override
  String get textSpeed => "Kecepatan teks";
  @override
  List<String> get textSpeeds => const ["Paling lambat", "Lambat", "Normal", "Cepat", "Lebih cepat", "Instan"];
  @override
  String get autoForwardDelay => "Jeda otomatis";
  @override
  String get skipUnread => "Lewati teks yang belum dibaca";
  @override
  String get skipUnreadHint => "Lewati juga mempercepat baris yang belum pernah kamu baca.";
  @override
  String get sound => "Suara";
  @override
  String get music => "Musik";
  @override
  String get soundEffects => "Efek suara";
  @override
  String get voice => "Suara karakter";
  @override
  String get characterVoices => "Suara tiap karakter";
  @override
  String get musicRoom => "Ruang musik";
  @override
  String get noMusic => "Cerita ini tidak punya musik.";
  @override
  String tracksHeard(int heard, int total) => "$heard / $total lagu sudah didengar";
  @override
  String track(int number) => "Lagu $number";
  @override
  String get notHeardYet => "Belum didengar";
}
