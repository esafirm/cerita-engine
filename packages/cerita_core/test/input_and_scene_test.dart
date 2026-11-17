import 'dart:convert';

import 'package:cerita_core/cerita_core.dart';
import 'package:test/test.dart';

InputItemType _input(Map<String, dynamic> fields) =>
    ItemType.fromJson({"type": "INPUT", "text": "Code?", "variable": "CODE", ...fields}) as InputItemType;

void main() {
  group('INPUT keyboard and length', () {
    test('reads keyboard, min_length and max_length', () {
      final item = _input({"keyboard": "digits", "min_length": 4, "max_length": 4});
      expect(item.keyboard, InputKeyboard.digits);
      expect(item.minLength, 4);
      expect(item.maxLength, 4);
    });

    test('defaults to any text of any length', () {
      final item = _input({});
      expect(item.keyboard, InputKeyboard.text);
      expect(item.minLength, isNull);
      expect(item.maxLength, isNull);
      expect(item.accepts(""), isTrue);
      expect(item.accepts("Alex 2"), isTrue);
      expect(_input({"keyboard": "emoji"}).keyboard, InputKeyboard.text, reason: "an unknown keyboard is text");
    });

    test('a four-digit code takes exactly four digits, leading zeros kept', () {
      final item = _input({"keyboard": "digits", "min_length": 4, "max_length": 4});
      expect(item.accepts("0530"), isTrue);
      expect(item.accepts("530"), isFalse);
      expect(item.accepts("05301"), isFalse);
      expect(item.accepts("05:3"), isFalse);
      expect(item.accepts(""), isFalse);
    });

    test('min_length alone sets a minimum for text', () {
      final item = _input({"min_length": 2});
      expect(item.accepts("A"), isFalse);
      expect(item.accepts("Al"), isTrue);
      expect(item.accepts("Alexandra"), isTrue);
    });

    test('a language switch keeps the limits', () {
      final item = _input({"keyboard": "digits", "max_length": 6}).localized(const Localizer(locale: "en"));
      expect((item as InputItemType).keyboard, InputKeyboard.digits);
      expect(item.maxLength, 6);
    });
  });

  group('scene status', () {
    test('no status keeps the channel status', () {
      expect(Scene.fromJson({"mode": "CHAT"}).status, isNull);
    });

    test('a status replaces it, in every language', () {
      final scene = Scene.fromJson({
        "mode": "CHAT",
        "status": {"id": "daring", "en": "online"},
      });
      expect(const Localizer(locale: "en").resolve(scene.status!), "online");
      expect(const Localizer(locale: "id").resolve(scene.status!), "daring");
    });

    test('null or empty hides it', () {
      expect(Scene.fromJson({"mode": "CHAT", "status": null}).status?.resolve(null), "");
      expect(Scene.fromJson({"mode": "CHAT", "status": ""}).status?.resolve(null), "");
    });

    test('saves and rollback frames keep the status, hidden included', () {
      for (final json in [
        {"mode": "CHAT", "status": null},
        {"mode": "CHAT", "status": {"id": "daring", "en": "online"}},
        {"mode": "CHAT"},
      ]) {
        final scene = Scene.fromJson(json);
        final restored = Scene.fromJson(jsonDecode(jsonEncode(scene.toJson())) as Map<String, dynamic>);
        expect(restored.status?.toJson(), scene.status?.toJson(), reason: "$json");
      }
    });
  });
}
