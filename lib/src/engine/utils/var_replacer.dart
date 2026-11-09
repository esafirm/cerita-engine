final variablePattern = RegExp(r"{{([a-zA-Z]+)}}");

extension VariableReplacer on String {
  String replaceWithVars(Map<String, String> dataMap) {
    return replaceAllMapped(variablePattern, (match) {
      final varName = match.group(1);
      final data = dataMap[varName];
      if (data == null) {
        throw Exception("Variable $varName not exist in data map");
      }
      return data;
    });
  }
}

