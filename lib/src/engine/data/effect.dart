/// A state mutation applied to the engine data map.
class Effect {
  final String variable;
  final EffectOp op;
  final dynamic value;

  const Effect(this.variable, this.op, [this.value]);

  factory Effect.fromJson(Map<String, dynamic> json) {
    return Effect(
      json["variable"] as String,
      EffectOp.fromName(json["op"] as String? ?? "set"),
      json["value"],
    );
  }

  static List<Effect> listFromJson(dynamic json) {
    if (json is! List) return const [];
    return json.map((e) => Effect.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  void apply(Map<String, dynamic> dataMap) {
    switch (op) {
      case EffectOp.set:
        dataMap[variable] = value;
      case EffectOp.add:
        dataMap[variable] = _number(dataMap[variable]) + _number(value);
      case EffectOp.subtract:
        dataMap[variable] = _number(dataMap[variable]) - _number(value);
      case EffectOp.toggle:
        dataMap[variable] = !(dataMap[variable] == true);
    }
  }

  num _number(dynamic raw) => switch (raw) {
        num n => n,
        String s => num.tryParse(s) ?? 0,
        _ => 0,
      };
}

enum EffectOp {
  set,
  add,
  subtract,
  toggle;

  static EffectOp fromName(String name) =>
      values.where((op) => op.name == name).firstOrNull ?? (throw Exception("Unknown effect op '$name'"));
}
