import 'dart:ui' show PlatformDispatcher;

import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../player_prefs.dart';
import '../story_setup.dart';
import 'cerita_strings.dart';

/// The player's language: which locale story text and voice clips use, and the engine's own strings.
/// Provide it above the navigator with [StoryLanguageScope]. See `specs/presentation-modes.md` section 5.
class StoryLanguage extends ChangeNotifier {
  /// What widgets get without a [StoryLanguageScope]: English engine screens and the story in its
  /// source language.
  static final StoryLanguage fallback = StoryLanguage();

  final Map<String, CeritaStrings> _strings;
  PlayerPrefs? _prefs;
  StoryLocales _locales;
  String? _locale;

  /// [strings] adds engine strings for more languages, or replaces built-in ones, by locale code.
  StoryLanguage({this._locale, this._locales = const StoryLocales(), Map<String, CeritaStrings> strings = const {}})
      : _strings = {...CeritaStrings.builtIn, ...strings};

  static StoryLanguage of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoryLanguageScope>()?.notifier ?? fallback;

  /// The active locale. Null until [load] or [select]: the story then shows its source language.
  String? get locale => _locale;

  /// The story's languages, read by [load].
  StoryLocales get locales => _locales;

  /// The languages the player can pick.
  List<String> get available => _locales.supported;

  Localizer get localizer => Localizer(locale: _locale, sourceLocale: _locales.source);

  /// Engine strings in the active locale, else English.
  CeritaStrings get strings => stringsFor(_locale);

  CeritaStrings stringsFor(String? locale) {
    if (locale == null) return _strings["en"] ?? CeritaStrings.en;
    if (_strings[locale] case final exact?) return exact;
    final dash = locale.indexOf("-");
    if (dash > 0) {
      if (_strings[locale.substring(0, dash)] case final base?) return base;
    }
    return _strings["en"] ?? CeritaStrings.en;
  }

  /// [locale]'s own name, or its code when no engine strings exist for it.
  String languageName(String locale) => _strings[locale]?.languageName ?? locale;

  /// Story text in the active locale.
  String text(LocalizedText text) => localizer.resolve(text);

  String? maybe(LocalizedText? text) => localizer.maybe(text);

  /// Reads the story's languages from `index.json` and picks the first the story offers of: the saved
  /// language (`PlayerSettings.locale`), [deviceLocale] (the platform's language when omitted), the story's
  /// source language.
  Future<void> load(StorySetup setup, {String? deviceLocale}) async {
    _prefs = setup.settings;
    _locales = (await setup.loader.loadConversation(Conversation.indexKey)).locales;
    await setup.assets.preload();
    await setup.settings.load();
    final saved = setup.settings.value.locale;
    final candidates = [saved, deviceLocale ?? PlatformDispatcher.instance.locale.languageCode];
    _locale = candidates.whereType<String>().where(_locales.supports).firstOrNull ?? _locales.source;
    notifyListeners();
  }

  /// Switches to [locale] and saves it in the player settings, so it outlives the app and every playthrough.
  Future<void> select(String locale) async {
    if (locale == _locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = _prefs;
    if (prefs != null) await prefs.update(prefs.value.copyWith(locale: locale));
  }
}

/// Provides a [StoryLanguage] and rebuilds its dependents when the player switches language.
class StoryLanguageScope extends InheritedNotifier<StoryLanguage> {
  const StoryLanguageScope({super.key, required StoryLanguage language, required super.child})
      : super(notifier: language);
}

/// Lets the player pick one of the story's languages.
class LanguagePicker {
  static Future<void> show(BuildContext context) {
    final language = StoryLanguage.of(context);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(language.strings.language),
        children: [
          for (final locale in language.available)
            ListTile(
              title: Text(language.languageName(locale)),
              trailing: locale == language.locale ? const Icon(Icons.check) : null,
              onTap: () {
                Navigator.of(dialogContext).pop();
                language.select(locale);
              },
            ),
        ],
      ),
    );
  }
}
