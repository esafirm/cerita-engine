final variablePattern = RegExp(r"{{([a-zA-Z0-9_]+)}}");

extension VariableReplacer on String {
  String replaceWithVars(Map<String, dynamic> dataMap) {
    return replaceAllMapped(variablePattern, (match) {
      final varName = match.group(1);
      final data = dataMap[varName];
      if (data == null) {
        throw Exception("Variable $varName not exist in data map");
      }
      return data.toString();
    });
  }
}

/// Interpolates the user-facing string fields of a raw item JSON.
/// Logic fields (`condition`, `variable`, `target`, `uri`, `effects`) are left untouched.
Map<String, dynamic> interpolateItemJson(Map<String, dynamic> json, Map<String, dynamic> dataMap) {
  const textKeys = {"text", "caption", "transcript", "title", "summary", "notification_text", "default_value"};

  dynamic replace(String key, dynamic value) =>
      textKeys.contains(key) && value is String ? value.replaceWithVars(dataMap) : value;

  final result = json.map((key, value) => MapEntry(key, replace(key, value)));
  final choices = json["choices"];
  if (choices is List) {
    result["choices"] = choices.map((raw) {
      final choice = Map<String, dynamic>.from(raw as Map);
      return choice.map((key, value) {
        if (key == "value" && value is String) return MapEntry(key, value.replaceWithVars(dataMap));
        return MapEntry(key, replace(key, value));
      });
    }).toList();
  }
  return result;
}
