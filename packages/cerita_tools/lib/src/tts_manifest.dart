import 'package:cerita_core/cerita_core.dart' show TextMarkup;

import 'diagnostics.dart';
import 'model.dart';
import 'project.dart';

/// Every voiced line, one entry per line and locale, for the voice pipeline (spec §3.4).
///
/// Each entry's `file` is the per-locale clip the player looks for first, `name.<locale>.ext` (CE-01, data schema
/// §5.4). Lines that can't be voiced (no speaker, no text in a locale) are reported to [diagnostics] as warnings.
Map<String, Object?> buildTtsManifest(StoryProject project, Diagnostics diagnostics) {
  final config = project.config;
  final lines = <Map<String, Object?>>[];
  final firstUse = <String, (String, SourceSpan)>{};

  void add({
    required String kind,
    required ConversationNode conversation,
    required ItemNode item,
    required ProfileRef? speaker,
    required String clip,
    required Localized? text,
    required Localized? tts,
    required String? delivery,
  }) {
    if (speaker == null) diagnostics.warning(item.span, "Voice note without a speaker: add by=");
    final profile = speaker == null ? null : project.cast[speaker.speaker];
    for (final locale in config.locales) {
      final value = text?.values[locale];
      if (value == null) {
        diagnostics.warning(item.span, "No '$locale' text to voice for '${localeVariant(clip, locale)}'");
        continue;
      }
      final file = localeVariant(clip, locale);
      final (firstText, firstSpan) = firstUse.putIfAbsent(file, () => (value, item.span));
      if (firstText != value) {
        diagnostics.warning(item.span, "'$file' is also voiced at $firstSpan with other text, so one of them won't match");
      }
      lines.add({
        "id": _stem(clip),
        "file": file,
        "kind": kind,
        "speaker": speaker?.speaker,
        "speaker_name": ?profile?.name?.textFor(locale, config.sourceLocale),
        "locale": locale,
        // Text tags such as {w=400} or {i} style the line on screen. They aren't spoken.
        "text": TextMarkup.plain(value),
        "tts_text": ?tts?.values[locale],
        "delivery": ?delivery,
        "conversation": conversation.key,
        "source": item.span.toString(),
      });
    }
  }

  for (final conversation in project.conversations) {
    for (final item in conversation.items) {
      switch (item) {
        case LineItem(voice: final voice?):
          add(
            kind: "line",
            conversation: conversation,
            item: item,
            speaker: item.speaker,
            clip: voice,
            text: item.texts["text"],
            tts: item.texts["tts"],
            delivery: item.delivery,
          );
        case MediaItem(isVoiceNote: true):
          add(
            kind: "voice_note",
            conversation: conversation,
            item: item,
            speaker: item.by,
            clip: item.uri,
            text: item.texts["transcript"],
            tts: item.texts["tts"],
            delivery: item.delivery,
          );
        default:
          break;
      }
    }
  }
  return {"lines": lines};
}

String _stem(String file) {
  final name = file.split("/").last;
  final dot = name.lastIndexOf(".");
  return dot > 0 ? name.substring(0, dot) : name;
}
