import 'dart:convert';

import 'package:cerita_tools/cerita_tools.dart';
import 'package:test/test.dart';

import 'support.dart';

/// The INPUT a one-statement `input` line compiles to, or the errors.
Object _input(String header) {
  final result = compileStory(story({
    "a.cerita": """
@conversation index
$header
  en: Enter the four-digit code.
""",
  }));
  final errors = result.diagnostics.sorted().where((d) => d.severity == Severity.error).map((d) => d.format());
  if (errors.isNotEmpty) return errors.toList();
  final json = jsonDecode(result.files["index.json"]!) as Map<String, dynamic>;
  return (json["conversations"] as List).single as Map<String, dynamic>;
}

void main() {
  test('keyboard=digits length=4 asks for exactly four digits', () {
    expect(_input("input CODE keyboard=digits length=4"), {
      "type": "INPUT",
      "text": "Enter the four-digit code.",
      "variable": "CODE",
      "keyboard": "digits",
      "min_length": 4,
      "max_length": 4,
    });
  });

  test('min_length and max_length on their own', () {
    final json = _input("input NAME min_length=2 max_length=12") as Map;
    expect(json["min_length"], 2);
    expect(json["max_length"], 12);
    expect(json.containsKey("keyboard"), isFalse);
    expect((_input("input NAME max_length=12") as Map).containsKey("min_length"), isFalse);
  });

  test('keyboard=text is the default and is left out', () {
    expect((_input("input NAME keyboard=text") as Map).containsKey("keyboard"), isFalse);
    expect((_input("input NAME") as Map).keys, ["type", "text", "variable"]);
  });

  test('reports bad keyboards and lengths', () {
    expect(_input("input CODE keyboard=pin"), ["a.cerita:2: error: Unknown keyboard 'pin'. Use text, digits"]);
    expect(_input("input CODE length=0"), ["a.cerita:2: error: length must be a whole number from 1, not '0'"]);
    expect(_input("input CODE max_length=four"),
        ["a.cerita:2: error: max_length must be a whole number from 1, not 'four'"]);
    expect(_input("input CODE min_length=6 max_length=4"), ["a.cerita:2: error: min_length (6) is more than max_length (4)"]);
    expect(_input("input CODE length=4 max_length=6"),
        ["a.cerita:2: error: Use length= or min_length= and max_length=, not both"]);
  });
}
