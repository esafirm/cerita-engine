import 'diagnostics.dart';
import 'model.dart';
import 'project.dart';

/// Every voiced line, one entry per line and locale, for the voice pipeline (spec §3.4). Lines that can't be
/// voiced (no text, no speaker) are reported to [diagnostics] as warnings and left out.
Map<String, Object?> buildTtsManifest(StoryProject project, Diagnostics diagnostics) {
  final config = project.config;
  final lines = <Map<String, Object?>>[];

  void add({
    required String kind,
    required ConversationNode conversation,
    required ItemNode item,
    required ProfileRef? speaker,
    required LocalizedAsset clip,
    required Localized? text,
    required Localized? tts,
    required String? delivery,
  }) {
    if (speaker == null) diagnostics.warning(item.span, "Voice note without a speaker: add by=");
    final files = clip.resolve(config.locales, config.sourceLocale);
    for (final MapEntry(key: locale, value: file) in files.entries) {
      final value = text?.values[locale];
      if (value == null) {
        diagnostics.warning(item.span, "No '$locale' text to voice for '$file'");
        continue;
      }
      final profile = speaker == null ? null : project.cast[speaker.speaker];
      final name = profile?.name?.textFor(locale, config.sourceLocale);
      lines.add({
        "id": _stem(file),
        "file": file,
        "kind": kind,
        "speaker": speaker?.speaker,
        "speaker_name": ?name,
        "locale": locale,
        "text": value,
        if (tts?.values[locale] != null) "tts_text": tts!.values[locale],
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
