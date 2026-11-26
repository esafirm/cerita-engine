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

  static const _maxCachedExprs = 512;
  static final Map<String, _Expr> _astCache = {};

  /// Why [expression] can't be evaluated whatever the variables hold: bad syntax, an unknown function
  /// or wrong arguments. Null when it is fine. Errors that depend on the values (division by zero,
  /// comparing a string with a number) are not reported.
  static String? syntaxError(String expression) {
    try {
      _parseExpr(expression);
      return null;
    } on ConditionException catch (error) {
      return error.message;
    }
  }

  static _Expr _parseExpr(String expression) {
    final cached = _astCache[expression];
    if (cached != null) return cached;
    final parser = _Parser(_tokenize(expression), expression);
    final expr = parser.parseOr();
    parser.expectEnd();
    if (_astCache.length >= _maxCachedExprs) _astCache.clear();
    _astCache[expression] = expr;
    return expr;
  }

  dynamic _run(String expression, Map<String, dynamic> dataMap) =>
      _parseExpr(expression).eval(dataMap, expression, random);
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
final _numberPattern = RegExp(r"\d+(\.\d+)?");
final _identifierPattern = RegExp(r"[a-zA-Z_][a-zA-Z0-9_.]*");

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
    String? op;
    for (final candidate in _operators) {
      if (source.startsWith(candidate, i)) {
        op = candidate;
        break;
      }
    }
    if (op != null) {
      tokens.add(_Token(_TokenType.op, op));
      i += op.length;
      continue;
    }
    final number = _numberPattern.matchAsPrefix(source, i);
    if (number != null) {
      tokens.add(_Token(_TokenType.number, number.group(0)!));
      i = number.end;
      continue;
    }
    final identifier = _identifierPattern.matchAsPrefix(source, i);
    if (identifier != null) {
      tokens.add(_Token(_TokenType.identifier, identifier.group(0)!));
      i = identifier.end;
      continue;
    }
    throw ConditionException("Unexpected '$char' in '$source'");
  }
  return tokens;
}

sealed class _Expr {
  const _Expr();
  dynamic eval(Map<String, dynamic> dataMap, String source, Random random);
}

final class _LiteralExpr extends _Expr {
  final dynamic value;
  const _LiteralExpr(this.value);
  @override
  dynamic eval(Map<String, dynamic> dataMap, String source, Random random) => value;
}

final class _VarExpr extends _Expr {
  final String name;
  const _VarExpr(this.name);
  @override
  dynamic eval(Map<String, dynamic> dataMap, String source, Random random) =>
      dataMap.containsKey(name) ? dataMap[name] : _unset;
}

final class _UnaryExpr extends _Expr {
  final String op;
  final _Expr operand;
  const _UnaryExpr(this.op, this.operand);
  @override
  dynamic eval(Map<String, dynamic> dataMap, String source, Random random) {
    final val = operand.eval(dataMap, source, random);
    return op == "-" ? -_number(val, "-", source) : !_truthy(val);
  }
}

final class _LogicalExpr extends _Expr {
  final String op;
  final _Expr left;
  final _Expr right;
  const _LogicalExpr(this.op, this.left, this.right);
  @override
  dynamic eval(Map<String, dynamic> dataMap, String source, Random random) {
    final l = _truthy(left.eval(dataMap, source, random));
    if (op == "||") return l || _truthy(right.eval(dataMap, source, random));
    return l && _truthy(right.eval(dataMap, source, random));
  }
}

final class _BinaryExpr extends _Expr {
  final String op;
  final _Expr left;
  final _Expr right;
  const _BinaryExpr(this.op, this.left, this.right);
  @override
  dynamic eval(Map<String, dynamic> dataMap, String source, Random random) {
    final l = left.eval(dataMap, source, random);
    final r = right.eval(dataMap, source, random);
    return switch (op) {
      "==" || "!=" || ">" || ">=" || "<" || "<=" => _compare(l, op, r, source),
      "+" => l is String || r is String
          ? "${_display(l)}${_display(r)}"
          : _number(l, "+", source) + _number(r, "+", source),
      "-" => _number(l, "-", source) - _number(r, "-", source),
      "*" => _number(l, "*", source) * _number(r, "*", source),
      "/" => () {
          final a = _number(l, "/", source);
          final b = _number(r, "/", source);
          if (b == 0) throw ConditionException("Division by zero in '$source'");
          return _whole(a / b);
        }(),
      _ => () {
          final a = _number(l, "%", source);
          final b = _number(r, "%", source);
          if (b == 0) throw ConditionException("Modulo by zero in '$source'");
          return a % b;
        }(),
    };
  }
}

final class _CallExpr extends _Expr {
  final String name;
  final List<_Expr> args;
  const _CallExpr(this.name, this.args);
  @override
  dynamic eval(Map<String, dynamic> dataMap, String source, Random random) {
    final values = [for (final arg in args) _number(arg.eval(dataMap, source, random), name, source)];
    return switch (name) {
      "random" => () {
          final low = values[0].floor(), high = values[1].floor();
          if (high < low) throw ConditionException("random($low, $high) has an empty range in '$source'");
          return low + random.nextInt(high - low + 1);
        }(),
      "min" => values.reduce(min),
      "max" => values.reduce(max),
      "abs" => values[0].abs(),
      "floor" => values[0].floor(),
      "ceil" => values[0].ceil(),
      _ => values[0].round(),
    };
  }
}

/// Unset variables count as `0` in arithmetic.
num _number(dynamic value, String op, String source) => switch (value) {
      num n => n,
      _Unset() || null => 0,
      _ => throw ConditionException("Can't use '$value' with '$op' in '$source'"),
    };

/// Keeps `4 / 2` an int, so it can be compared and shown as `2`.
num _whole(double value) => value.isFinite && value == value.truncateToDouble() ? value.toInt() : value;

String _display(dynamic value) => value is _Unset || value == null ? "" : value.toString();

bool _compare(dynamic left, String op, dynamic right, String source) {
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

class _Parser {
  final List<_Token> tokens;
  final String source;
  int pos = 0;

  _Parser(this.tokens, this.source);

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

  _Expr parseOr() {
    var left = parseAnd();
    while (_matchOp("||")) {
      left = _LogicalExpr("||", left, parseAnd());
    }
    return left;
  }

  _Expr parseAnd() {
    var left = parseComparison();
    while (_matchOp("&&")) {
      left = _LogicalExpr("&&", left, parseComparison());
    }
    return left;
  }

  _Expr parseComparison() {
    final left = parseAdditive();
    final token = _peek;
    if (token == null || token.type != _TokenType.op) return left;
    const comparators = {"==", "!=", ">", ">=", "<", "<="};
    if (!comparators.contains(token.text)) return left;
    pos++;
    return _BinaryExpr(token.text, left, parseAdditive());
  }

  _Expr parseAdditive() {
    var left = parseMultiplicative();
    while (true) {
      if (_matchOp("+")) {
        left = _BinaryExpr("+", left, parseMultiplicative());
      } else if (_matchOp("-")) {
        left = _BinaryExpr("-", left, parseMultiplicative());
      } else {
        return left;
      }
    }
  }

  _Expr parseMultiplicative() {
    var left = parseUnary();
    while (true) {
      final token = _peek;
      if (token == null || token.type != _TokenType.op || !const {"*", "/", "%"}.contains(token.text)) return left;
      pos++;
      left = _BinaryExpr(token.text, left, parseUnary());
    }
  }

  _Expr parseUnary() {
    if (_matchOp("-")) return _UnaryExpr("-", parseUnary());
    if (_matchOp("!")) return _UnaryExpr("!", parseUnary());
    return parsePrimary();
  }

  _Expr parsePrimary() {
    final token = _peek;
    if (token == null) throw ConditionException("Unexpected end of '$source'");
    pos++;
    switch (token.type) {
      case _TokenType.number:
        return _LiteralExpr(num.parse(token.text));
      case _TokenType.string:
        return _LiteralExpr(token.text);
      case _TokenType.identifier:
        if (token.text == "true") return const _LiteralExpr(true);
        if (token.text == "false") return const _LiteralExpr(false);
        if (_peek?.type == _TokenType.lParen) return _call(token.text);
        return _VarExpr(token.text);
      case _TokenType.lParen:
        final expr = parseOr();
        _expect(_TokenType.rParen, ")");
        return expr;
      default:
        throw ConditionException("Unexpected '${token.text}' in '$source'");
    }
  }

  _Expr _call(String name) {
    _expect(_TokenType.lParen, "(");
    final args = <_Expr>[];
    if (_peek?.type != _TokenType.rParen) {
      args.add(parseOr());
      while (_peek?.type == _TokenType.comma) {
        pos++;
        args.add(parseOr());
      }
    }
    _expect(_TokenType.rParen, ")");

    void arity(int count) {
      if (args.length != count) throw ConditionException("$name() takes $count argument(s) in '$source'");
    }

    switch (name) {
      case "random":
        arity(2);
      case "min" || "max":
        if (args.isEmpty) throw ConditionException("$name() needs arguments in '$source'");
      case "abs" || "floor" || "ceil" || "round":
        arity(1);
      default:
        throw ConditionException("Unknown function '$name' in '$source'");
    }
    return _CallExpr(name, args);
  }
}
