import 'package:cerita_flutter/cerita_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plays Last Seen headlessly in [locale], picking each choice by its `value` from [picks] (else the first
/// available option), so every route and JSON file is exercised.
Future<(EndingItemType, RealFsseEngine)> _play(String locale, Map<String, String> picks) async {
  final engine = RealFsseEngine(AssetEngineLoader(const LoaderConfig()))..locale = locale;
  ItemResult? result;
  for (var step = 0; step < 500; step++) {
    final item = await engine.next(prevResult: result);
    result = null;
    switch (item) {
      case EndingItemType():
        return (item, engine);
      case ChoiceItemType():
        final wanted = picks[item.variable];
        final choice = item.availableChoices.firstWhere((c) => c.value == wanted, orElse: () => item.availableChoices.first);
        expect(choice.locked, isFalse, reason: "'${choice.text}' is locked");
        result = ItemResult.choice(item.variable, choice);
      default:
        break;
    }
  }
  fail("No ending reached");
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every text tag in the story is a known tag, in both languages', () async {
    for (final locale in ["id", "en"]) {
      final engine = RealFsseEngine(AssetEngineLoader(const LoaderConfig()))..locale = locale;
      final catalog = await StoryCatalog.load(engine.loader);
      for (final conversation in catalog.conversations) {
        for (final item in conversation.conversations) {
          final text = item.getText()?.replaceAll(variablePattern, "");
          if (text == null) continue;
          expect(TextMarkup.plain(text), isNot(contains("{")), reason: "'$text' in ${conversation.key}");
        }
      }
    }
  });

  for (final locale in ["id", "en"]) {
    test('prologue, kind route ($locale): Dinda trusts Raka', () async {
      final (ending, engine) = await _play(locale, {
        "FALLOUT": "silent",
        "UNSENT": "sorry",
        "FIRST_REPLY": "worried",
        "CALL_REACT": "safe",
        "ANSWER": "now",
      });
      expect(ending.endingId, "end_00_preview");
      expect(engine.dataMap["trust_dinda"], 12);
      expect(engine.dataMap["FALLOUT"], "silent");
    });

    test('prologue, cold route ($locale): Dinda trusts Raka less', () async {
      final (ending, engine) = await _play(locale, {
        "FALLOUT": "cruel",
        "UNSENT": "closed",
        "FIRST_REPLY": "guarded",
        "CALL_REACT": "alone",
        "ANSWER": "silent",
      });
      expect(ending.endingId, "end_00_preview");
      expect(engine.dataMap["trust_dinda"], -5);
    });
  }
}
