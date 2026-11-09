/// Evaluates boolean expressions such as `miki_trust >= 10 && PILL == 'Blue'`
/// against the engine data map.
///
/// Supports `==`, `!=`, `>`, `>=`, `<`, `<=`, `&&`, `||`, `!`, parentheses,
/// numbers, `'single'`/`"double"` quoted strings, `true` and `false`.
/// Unset variables compare as `0` against numbers and `false` against booleans.
class ConditionEvaluator {
  const ConditionEvaluator();

  bool evaluate(String? expression, Map<String, dynamic> dataMap) {
    if (expression == null || expression.trim().isEmpty) return true;
    final parser = _Parser(_tokenize(expression), dataMap, expression);
    final result = parser.parseOr();
    parser.expectEnd();
    return _truthy(result);
  }
}

class ConditionException implements Exception {
  final String message;

  const ConditionException(this.message);

  @override
  String toString() => "ConditionException: $message";
}

/// Marker for a variable that is not in the data map yet.
class _Unset {
  const _Unset();
}

const _unset = _Unset();

bool _truthy(dynamic value) => switch (value) {
      _Unset() || null => false,
      bool b => b,
      num n => n != 0,
      String s => s.isNotEmpty,
      _ => true,
    };

enum _TokenType { number, string, identifier, op, lParen, rParen }

class _Token {
  final _TokenType type;
  final String text;

  const _Token(this.type, this.text);
}

const _operators = ["==", "!=", ">=", "<=", "&&", "||", ">", "<", "!"];

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
      tokens.add(_Token(char == "(" ? _TokenType.lParen : _TokenType.rParen, char));
      i++;
      continue;
    }
    if (char == "'" || char == '"') {
      final end = source.indexOf(char, i + 1);
      if (end < 0) throw ConditionException("Unterminated string in '$source'");
      tokens.add(_Token(_TokenType.string, source.substring(i + 1, end)));
      i = end + 1;
      continue;
    }
    final op = _operators.where((op) => source.startsWith(op, i)).firstOrNull;
    if (op != null) {
      tokens.add(_Token(_TokenType.op, op));
      i += op.length;
      continue;
    }
    final number = RegExp(r"-?\d+(\.\d+)?").matchAsPrefix(source, i);
    if (number != null) {
      tokens.add(_Token(_TokenType.number, number.group(0)!));
      i = number.end;
      continue;
    }
    final identifier = RegExp(r"[a-zA-Z_][a-zA-Z0-9_]*").matchAsPrefix(source, i);
    if (identifier != null) {
      tokens.add(_Token(_TokenType.identifier, identifier.group(0)!));
      i = identifier.end;
      continue;
    }
    throw ConditionException("Unexpected '$char' in '$source'");
  }
  return tokens;
}

class _Parser {
  final List<_Token> tokens;
  final Map<String, dynamic> dataMap;
  final String source;
  int pos = 0;

  _Parser(this.tokens, this.dataMap, this.source);

  _Token? get _peek => pos < tokens.length ? tokens[pos] : null;

  bool _matchOp(String op) {
    final token = _peek;
    if (token != null && token.type == _TokenType.op && token.text == op) {
      pos++;
      return true;
    }
    return false;
  }

  void expectEnd() {
    if (pos != tokens.length) throw ConditionException("Unexpected '${tokens[pos].text}' in '$source'");
  }

  dynamic parseOr() {
    var left = parseAnd();
    while (_matchOp("||")) {
      final right = parseAnd();
      left = _truthy(left) || _truthy(right);
    }
    return left;
  }

  dynamic parseAnd() {
    var left = parseNot();
    while (_matchOp("&&")) {
      final right = parseNot();
      left = _truthy(left) && _truthy(right);
    }
    return left;
  }

  dynamic parseNot() {
    if (_matchOp("!")) return !_truthy(parseNot());
    return parseComparison();
  }

  dynamic parseComparison() {
    final left = parsePrimary();
    final token = _peek;
    if (token == null || token.type != _TokenType.op) return left;
    const comparators = {"==", "!=", ">", ">=", "<", "<="};
    if (!comparators.contains(token.text)) return left;
    pos++;
    return _compare(left, token.text, parsePrimary());
  }

  dynamic parsePrimary() {
    final token = _peek;
    if (token == null) throw ConditionException("Unexpected end of '$source'");
    pos++;
    switch (token.type) {
      case _TokenType.number:
        return num.parse(token.text);
      case _TokenType.string:
        return token.text;
      case _TokenType.identifier:
        if (token.text == "true") return true;
        if (token.text == "false") return false;
        return dataMap.containsKey(token.text) ? dataMap[token.text] : _unset;
      case _TokenType.lParen:
        final value = parseOr();
        if (_peek?.type != _TokenType.rParen) throw ConditionException("Missing ')' in '$source'");
        pos++;
        return value;
      default:
        throw ConditionException("Unexpected '${token.text}' in '$source'");
    }
  }

  bool _compare(dynamic left, String op, dynamic right) {
    left = _coerceUnset(left, right);
    right = _coerceUnset(right, left);

    if (left is num && right is num) {
      return switch (op) {
        "==" => left == right,
        "!=" => left != right,
        ">" => left > right,
        ">=" => left >= right,
        "<" => left < right,
        _ => left <= right,
      };
    }
    return switch (op) {
      "==" => left == right,
      "!=" => left != right,
      _ => throw ConditionException("Can't compare $left $op $right in '$source'"),
    };
  }

  /// Unset variables default to `0` next to numbers, `false` next to booleans
  /// and `""` next to strings.
  dynamic _coerceUnset(dynamic value, dynamic other) {
    if (value is! _Unset) return value;
    return switch (other) {
      num() => 0,
      String() => "",
      _ => false,
    };
  }
}
