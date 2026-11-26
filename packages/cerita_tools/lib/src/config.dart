import 'package:yaml/yaml.dart';

import 'diagnostics.dart';
import 'model.dart';

final localePattern = RegExp(r"^[a-z]{2,3}(-[A-Za-z0-9]+)?$");

SourceSpan yamlSpan(String file, YamlNode? node) => SourceSpan(file, (node?.span.start.line ?? 0) + 1);

/// Parses a YAML document, reporting syntax errors instead of throwing. Returns `null` on failure.
YamlNode? parseYaml(String file, String source, Diagnostics diagnostics) {
  try {
    return loadYamlNode(source, sourceUrl: Uri.file(file));
  } on YamlException catch (e) {
    diagnostics.error(SourceSpan(file, (e.span?.start.line ?? 0) + 1), "Invalid YAML: ${e.message}");
    return null;
  }
}

/// Reading speed and pacing used by `stats` (spec §3.2).
class StatsConfig {
  static const defaultWpm = 200;

  final Map<String, num> wpm;
  final num choiceSeconds;
  final num inputSeconds;
  final num mediaSeconds;

  const StatsConfig({this.wpm = const {}, this.choiceSeconds = 4, this.inputSeconds = 8, this.mediaSeconds = 4});

  num wpmFor(String locale) => wpm[locale] ?? defaultWpm;
}

/// `cerita.yaml`: the story settings (spec §1.1).
class StoryConfig {
  static const fileName = "cerita.yaml";
  static const defaultSourceLocale = "id";
  static const defaultAssetPrefix = "assets/story/";

  final String sourceLocale;
  final List<String> locales;
  final String? out;
  final String? assets;
  final String assetPrefix;
  final StatsConfig stats;

  const StoryConfig({
    this.sourceLocale = defaultSourceLocale,
    this.locales = const [defaultSourceLocale],
    this.out,
    this.assets,
    this.assetPrefix = defaultAssetPrefix,
    this.stats = const StatsConfig(),
  });

  bool get isMultiLocale => locales.length > 1;

  /// Builds a [Localized] from a YAML value: a plain string (the source locale) or a `{locale: text}` map.
  Localized? localizedFromYaml(String file, YamlNode? node, Diagnostics diagnostics, String what) {
    if (node == null || node.value == null) return null;
    final span = yamlSpan(file, node);
    if (node is YamlMap) {
      final result = Localized(span);
      node.nodes.forEach((key, value) {
        final locale = (key as YamlNode).value.toString();
        if (!locales.contains(locale)) diagnostics.error(yamlSpan(file, key), "Unknown locale '$locale' in $what");
        if (value.value == null) return;
        result.set(locale, value.value.toString(), yamlSpan(file, value));
      });
      return result;
    }
    if (node is YamlList) {
      diagnostics.error(span, "Expected text for $what");
      return null;
    }
    return Localized.single(span, sourceLocale, node.value.toString())..isPlain = true;
  }

  static StoryConfig parse(String? source, Diagnostics diagnostics) {
    const file = fileName;
    if (source == null) {
      diagnostics.error(null, "Missing $fileName in the story folder");
      return const StoryConfig();
    }
    final root = parseYaml(file, source, diagnostics);
    if (root == null || root.value == null) return const StoryConfig();
    if (root is! YamlMap) {
      diagnostics.error(yamlSpan(file, root), "$fileName must be a map");
      return const StoryConfig();
    }

    const known = {"source_locale", "locales", "out", "assets", "asset_prefix", "stats"};
    for (final key in root.nodes.keys.cast<YamlNode>()) {
      if (!known.contains(key.value)) diagnostics.error(yamlSpan(file, key), "Unknown setting '${key.value}'");
    }

    String? string(String key) {
      final node = root.nodes[key];
      if (node == null || node.value == null) return null;
      if (node.value is YamlMap || node.value is YamlList) {
        diagnostics.error(yamlSpan(file, node), "'$key' must be a string");
        return null;
      }
      return node.value.toString();
    }

    final source0 = string("source_locale") ?? defaultSourceLocale;
    if (!localePattern.hasMatch(source0)) {
      diagnostics.error(yamlSpan(file, root.nodes["source_locale"]), "Invalid locale code '$source0'");
    }

    var locales = <String>[source0];
    final localesNode = root.nodes["locales"];
    if (localesNode is YamlList) {
      locales = [for (final node in localesNode.nodes) node.value.toString()];
      for (final node in localesNode.nodes) {
        if (!localePattern.hasMatch(node.value.toString())) {
          diagnostics.error(yamlSpan(file, node), "Invalid locale code '${node.value}'");
        }
      }
      if (locales.toSet().length != locales.length) diagnostics.error(yamlSpan(file, localesNode), "Duplicate locale");
      if (!locales.contains(source0)) {
        diagnostics.error(yamlSpan(file, localesNode), "locales must include the source locale '$source0'");
        locales = [source0, ...locales];
      }
    } else if (localesNode != null) {
      diagnostics.error(yamlSpan(file, localesNode), "'locales' must be a list, e.g. [id, en]");
    }

    return StoryConfig(
      sourceLocale: source0,
      locales: List.unmodifiable(locales),
      out: string("out"),
      assets: string("assets"),
      assetPrefix: string("asset_prefix") ?? defaultAssetPrefix,
      stats: _parseStats(file, root.nodes["stats"], diagnostics),
    );
  }

  static StatsConfig _parseStats(String file, YamlNode? node, Diagnostics diagnostics) {
    if (node == null || node.value == null) return const StatsConfig();
    if (node is! YamlMap) {
      diagnostics.error(yamlSpan(file, node), "'stats' must be a map");
      return const StatsConfig();
    }
    num? number(YamlNode? value, String what) {
      if (value == null) return null;
      final raw = value.value;
      if (raw is num && raw > 0) return raw;
      diagnostics.error(yamlSpan(file, value), "'$what' must be a positive number");
      return null;
    }

    final wpm = <String, num>{};
    final wpmNode = node.nodes["wpm"];
    if (wpmNode is YamlMap) {
      wpmNode.nodes.forEach((key, value) {
        final speed = number(value, "wpm");
        if (speed != null) wpm[(key as YamlNode).value.toString()] = speed;
      });
    } else if (wpmNode != null) {
      diagnostics.error(yamlSpan(file, wpmNode), "'wpm' must map locales to words per minute, e.g. { id: 180 }");
    }
    const known = {"wpm", "choice_seconds", "input_seconds", "media_seconds"};
    for (final key in node.nodes.keys.cast<YamlNode>()) {
      if (!known.contains(key.value)) diagnostics.error(yamlSpan(file, key), "Unknown stats setting '${key.value}'");
    }
    const defaults = StatsConfig();
    return StatsConfig(
      wpm: wpm,
      choiceSeconds: number(node.nodes["choice_seconds"], "choice_seconds") ?? defaults.choiceSeconds,
      inputSeconds: number(node.nodes["input_seconds"], "input_seconds") ?? defaults.inputSeconds,
      mediaSeconds: number(node.nodes["media_seconds"], "media_seconds") ?? defaults.mediaSeconds,
    );
  }
}
