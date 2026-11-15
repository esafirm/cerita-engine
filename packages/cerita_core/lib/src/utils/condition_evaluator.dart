import 'dart:math';

/// Evaluates expressions such as `miki_trust >= 10 && PILL == 'Blue'` or `(a + b) * 2`
/// against the engine data map.
///
/// Supports `==`, `!=`, `>`, `>=`, `<`, `<=`, `&&`, `||`, `!`, `+`, `-`, `*`, `/`, `%`,
/// parentheses, numbers, `'single'`/`"double"` quoted strings, `true`, `false` and the functions
/// `random(min, max)`, `min`, `max`, `abs`, `floor`, `ceil` and `round`.
/// Unset variables compare as `0` against numbers and `false` against booleans.
class ConditionEvaluator {
  static final _defaultRandom = Random();

  final Random? _random;

  const ConditionEvaluator([this._random]);

  /// Source of `random()`.
  Random get random => _random ?? _defaultRandom;

  /// Evaluates [expression] as a condition. Empty or null expressions are true.
  bool evaluate(String? expression, Map<String, dynamic> dataMap) {
    if (expression == null || expression.trim().isEmpty) return true;
    return _truthy(_run(expression, dataMap));
  }

  /// Evaluates [expression] to its value. Unset variables evaluate to null.
  dynamic value(String expression, Map<String, dynamic> dataMap) {
    final result = _run(expression, dataMap);
    return result is _Unset ? null : result;
  }

  /// Variables [expression] reads, without function names. Empty if it doesn't tokenize.
  static Set<String> variablesOf(String expression) {
    final List<_Token> tokens;
    try {
      tokens = _tokenize(expression);
    } on ConditionException {
      return const {};
    }
    return {
      for (final (index, token) in tokens.indexed)
        if (token.type == _TokenType.identifier &&
            token.text != "true" &&
            token.text != "false" &&
            (index + 1 >= tokens.length || tokens[index + 1].type != _TokenType.lParen))
          token.text,
    };
  }

  /// Why [expression] can't be evaluated whatever the variables hold: bad syntax, an unknown function
  /// or wrong arguments. Null when it is fine. Errors that depend on the values (division by zero,
  /// comparing a string with a number) are not reported.
  static String? syntaxError(String expression) {
    try {
      const ConditionEvaluator().value(expression, const {});
      return null;
    } on ConditionException catch (error) {
      const valueErrors = ["Division by zero", "Can't compare", "Can't use"];
      final dependsOnValues = valueErrors.any(error.message.startsWith) || error.message.contains("empty range");
      return dependsOnValues ? null : error.message;
    }
  }

  dynamic _run(String expression, Map<String, dynamic> dataMap) {
    final parser = _Parser(_tokenize(expression), dataMap, expression, random);
    final result = parser.parseOr();
    parser.expectEnd();
    return result;
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

enum _TokenType { number, string, identifier, op, lParen, rParen, comma }

class _Token {
  final _TokenType type;
  final String text;

  const _Token(this.type, this.text);
}

const _operators = ["==", "!=", ">=", "<=", "&&", "||", ">", "<", "!", "+", "-", "*", "/", "%"];

List<_Token> _tokenize(String source) {
  final tokens = <_Token>[];
  var i = 0;
  while (i < source.length) {
    final char = source[i];
    if (char.trim().isEmpty) {
      i++;
      continue;
    }
    if (char == "(" || char == ")" || char == ",") {
      tokens.add(_Token(
        switch (char) {
          "(" => _TokenType.lParen,
          ")" => _TokenType.rParen,
          _ => _TokenType.comma,
        },
        char,
      ));
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
    final number = RegExp(r"\d+(\.\d+)?").matchAsPrefix(source, i);
    if (number != null) {
      tokens.add(_Token(_TokenType.number, number.group(0)!));
      i = number.end;
      continue;
    }
    final identifier = RegExp(r"[a-zA-Z_][a-zA-Z0-9_.]*").matchAsPrefix(source, i);
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
  final Random random;
  int pos = 0;

  _Parser(this.tokens, this.dataMap, this.source, this.random);

  _Token? get _peek => pos < tokens.length ? tokens[pos] : null;

  bool _matchOp(String op) {
    final token = _peek;
    if (token != null && token.type == _TokenType.op && token.text == op) {
      pos++;
      return true;
    }
    return false;
  }

  void _expect(_TokenType type, String what) {
    if (_peek?.type != type) throw ConditionException("Missing '$what' in '$source'");
    pos++;
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
    final left = parseAdditive();
    final token = _peek;
    if (token == null || token.type != _TokenType.op) return left;
    const comparators = {"==", "!=", ">", ">=", "<", "<="};
    if (!comparators.contains(token.text)) return left;
    pos++;
    return _compare(left, token.text, parseAdditive());
  }

  dynamic parseAdditive() {
    var left = parseMultiplicative();
    while (true) {
      if (_matchOp("+")) {
        final right = parseMultiplicative();
        left = left is String || right is String
            ? "${_display(left)}${_display(right)}"
            : _number(left, "+") + _number(right, "+");
      } else if (_matchOp("-")) {
        left = _number(left, "-") - _number(parseMultiplicative(), "-");
      } else {
        return left;
      }
    }
  }

  dynamic parseMultiplicative() {
    var left = parseUnary();
    while (true) {
      final token = _peek;
      if (token == null || token.type != _TokenType.op || !{"*", "/", "%"}.contains(token.text)) return left;
      pos++;
      final a = _number(left, token.text);
      final b = _number(parseUnary(), token.text);
      left = switch (token.text) {
        "*" => a * b,
        "/" => b == 0 ? throw ConditionException("Division by zero in '$source'") : _whole(a / b),
        _ => a % b,
      };
    }
  }

  dynamic parseUnary() {
    if (_matchOp("-")) return -_number(parseUnary(), "-");
    if (_matchOp("!")) return !_truthy(parseUnary());
    return parsePrimary();
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
        if (_peek?.type == _TokenType.lParen) return _call(token.text);
        return dataMap.containsKey(token.text) ? dataMap[token.text] : _unset;
      case _TokenType.lParen:
        final value = parseOr();
        _expect(_TokenType.rParen, ")");
        return value;
      default:
        throw ConditionException("Unexpected '${token.text}' in '$source'");
    }
  }

  dynamic _call(String name) {
    _expect(_TokenType.lParen, "(");
    final args = <num>[];
    if (_peek?.type != _TokenType.rParen) {
      args.add(_number(parseOr(), name));
      while (_peek?.type == _TokenType.comma) {
        pos++;
        args.add(_number(parseOr(), name));
      }
    }
    _expect(_TokenType.rParen, ")");

    void arity(int count) {
      if (args.length != count) throw ConditionException("$name() takes $count argument(s) in '$source'");
    }

    switch (name) {
      case "random":
        arity(2);
        final low = args[0].floor(), high = args[1].floor();
        if (high < low) throw ConditionException("random($low, $high) has an empty range in '$source'");
        return low + random.nextInt(high - low + 1);
      case "min" || "max":
        if (args.isEmpty) throw ConditionException("$name() needs arguments in '$source'");
        return args.reduce(name == "min" ? min : max);
      case "abs":
        arity(1);
        return args[0].abs();
      case "floor" || "ceil" || "round":
        arity(1);
        return switch (name) { "floor" => args[0].floor(), "ceil" => args[0].ceil(), _ => args[0].round() };
      default:
        throw ConditionException("Unknown function '$name' in '$source'");
    }
  }

  /// Unset variables count as `0` in arithmetic.
  num _number(dynamic value, String op) => switch (value) {
        num n => n,
        _Unset() || null => 0,
        _ => throw ConditionException("Can't use '$value' with '$op' in '$source'"),
      };

  /// Keeps `4 / 2` an int, so it can be compared and shown as `2`.
  num _whole(double value) => value == value.truncateToDouble() ? value.toInt() : value;

  String _display(dynamic value) => value is _Unset || value == null ? "" : value.toString();

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
