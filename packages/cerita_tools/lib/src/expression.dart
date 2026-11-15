/// Checks a condition against the engine's grammar (engine §3) and lists the names it reads.
///
/// Mirrors `ConditionEvaluator` in cerita_core, plus dotted names such as `meta.flag.x` (CE-03). Nothing is
/// evaluated: the toolkit only needs to know whether a condition parses and which variables it reads.
class ConditionInfo {
  /// Variable names in reading order, without `true` and `false`.
  final List<String> names;
  final String? error;

  const ConditionInfo(this.names, [this.error]);

  bool get isValid => error == null;

  static ConditionInfo analyze(String source) {
    try {
      final parser = _Parser(_tokenize(source), source);
      if (parser.tokens.isEmpty) throw const _ParseError("Empty condition");
      parser.parseOr();
      parser.expectEnd();
      return ConditionInfo(parser.names);
    } on _ParseError catch (e) {
      return ConditionInfo(const [], e.message);
    }
  }
}

/// Names of `{{VAR}}` placeholders in [text].
Iterable<String> interpolatedNames(String text) =>
    RegExp(r"{{([a-zA-Z0-9_]+)}}").allMatches(text).map((match) => match.group(1)!);

class _ParseError implements Exception {
  final String message;

  const _ParseError(this.message);
}

enum _Type { number, string, identifier, op, lParen, rParen }

class _Token {
  final _Type type;
  final String text;

  const _Token(this.type, this.text);
}

const _operators = ["==", "!=", ">=", "<=", "&&", "||", ">", "<", "!"];
const _comparators = {"==", "!=", ">", ">=", "<", "<="};

List<_Token> _tokenize(String source) {
  final tokens = <_Token>[];
  var i = 0;
  while (i < source.length) {
    final char = source[i];
    if (char.trim().isEmpty) {
      i++;
      continue;
    }
    if (char == "(" || char == ")") {
      tokens.add(_Token(char == "(" ? _Type.lParen : _Type.rParen, char));
      i++;
      continue;
    }
    if (char == "'" || char == '"') {
      final end = source.indexOf(char, i + 1);
      if (end < 0) throw const _ParseError("Unterminated string");
      tokens.add(_Token(_Type.string, source.substring(i + 1, end)));
      i = end + 1;
      continue;
    }
    final op = _operators.where((op) => source.startsWith(op, i)).firstOrNull;
    if (op != null) {
      tokens.add(_Token(_Type.op, op));
      i += op.length;
      continue;
    }
    final number = RegExp(r"-?\d+(\.\d+)?").matchAsPrefix(source, i);
    if (number != null) {
      tokens.add(_Token(_Type.number, number.group(0)!));
      i = number.end;
      continue;
    }
    final identifier = RegExp(r"[a-zA-Z_][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)*").matchAsPrefix(source, i);
    if (identifier != null) {
      tokens.add(_Token(_Type.identifier, identifier.group(0)!));
      i = identifier.end;
      continue;
    }
    throw _ParseError("Unexpected '$char'");
  }
  return tokens;
}

class _Parser {
  final List<_Token> tokens;
  final String source;
  final List<String> names = [];
  int pos = 0;

  _Parser(this.tokens, this.source);

  _Token? get _peek => pos < tokens.length ? tokens[pos] : null;

  bool _matchOp(String op) {
    final token = _peek;
    if (token != null && token.type == _Type.op && token.text == op) {
      pos++;
      return true;
    }
    return false;
  }

  void expectEnd() {
    if (pos != tokens.length) throw _ParseError("Unexpected '${tokens[pos].text}'");
  }

  void parseOr() {
    parseAnd();
    while (_matchOp("||")) {
      parseAnd();
    }
  }

  void parseAnd() {
    parseNot();
    while (_matchOp("&&")) {
      parseNot();
    }
  }

  void parseNot() {
    if (_matchOp("!")) return parseNot();
    parseComparison();
  }

  void parseComparison() {
    parsePrimary();
    final token = _peek;
    if (token != null && token.type == _Type.op && _comparators.contains(token.text)) {
      pos++;
      parsePrimary();
    }
  }

  void parsePrimary() {
    final token = _peek;
    if (token == null) throw const _ParseError("Unexpected end");
    pos++;
    switch (token.type) {
      case _Type.number || _Type.string:
        return;
      case _Type.identifier:
        if (token.text != "true" && token.text != "false") names.add(token.text);
      case _Type.lParen:
        parseOr();
        if (_peek?.type != _Type.rParen) throw const _ParseError("Missing ')'");
        pos++;
      default:
        throw _ParseError("Unexpected '${token.text}'");
    }
  }
}
