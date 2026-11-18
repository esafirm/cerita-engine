import 'package:yaml/yaml.dart';

import 'config.dart';
import 'diagnostics.dart';
import 'model.dart';

final _namePattern = RegExp(r"^[a-z_][a-z0-9_]*$");
final _expressionPattern = RegExp(r"^[A-Za-z0-9_-]+$");

/// One `profiles.yaml` entry: a character with named expressions (spec §1.2).
class CastProfile {
  final String key;
  final String id;
  final SourceSpan span;
  final Localized? name;
  final String? handle;
  final Localized? bio;
  final String? avatar;
  final SourceSpan? avatarSpan;

  /// Expression names in sprite order. Index in this list is the sprite index.
  final List<String> expressions;
  final List<String> sprites;
  final List<SourceSpan> spriteSpans;

  /// `height`: how tall the character is, in any unit the whole cast shares. Sizes the sprites against each other.
  final num? height;

  /// `head`: where the top of the hair and the chin are on the sprites, as shares of the sprite height from the top.
  final ({num top, num chin})? head;

  const CastProfile({
    required this.key,
    required this.id,
    required this.span,
    required this.expressions,
    required this.sprites,
    required this.spriteSpans,
    this.name,
    this.handle,
    this.bio,
    this.avatar,
    this.avatarSpan,
    this.height,
    this.head,
  });

  /// The sprite index of [expression], or 0 when it's `null`. `null` when the expression doesn't exist.
  int? spriteIndex(String? expression) {
    if (expression == null) return 0;
    final index = expressions.indexOf(expression);
    return index < 0 ? null : index;
  }
}

/// `profiles.yaml`, keyed by the names scripts use.
class Cast {
  static const fileName = "profiles.yaml";

  final Map<String, CastProfile> profiles;

  const Cast(this.profiles);

  CastProfile? operator [](String key) => profiles[key];

  static Cast parse(String? source, StoryConfig config, Diagnostics diagnostics) {
    const file = fileName;
    if (source == null) {
      diagnostics.error(null, "Missing $fileName in the story folder");
      return const Cast({});
    }
    final root = parseYaml(file, source, diagnostics);
    if (root == null || root.value == null) return const Cast({});
    if (root is! YamlMap) {
      diagnostics.error(yamlSpan(file, root), "$fileName must map character names to profiles");
      return const Cast({});
    }

    final profiles = <String, CastProfile>{};
    final ids = <String, String>{};
    root.nodes.forEach((keyNode, node) {
      final key = (keyNode as YamlNode).value.toString();
      final span = yamlSpan(file, keyNode);
      if (!_namePattern.hasMatch(key)) {
        diagnostics.error(span, "Invalid character name '$key': use lowercase letters, digits and _");
      } else if (key == ProfileRef.player) {
        diagnostics.error(span, "'player' is built in and can't be declared");
      } else if (statementKeywords.contains(key)) {
        diagnostics.error(span, "'$key' is a statement keyword and can't be a character name");
      }
      if (node is! YamlMap) {
        diagnostics.error(span, "Profile '$key' must be a map");
        return;
      }
      const known = {"id", "name", "handle", "bio", "avatar", "expressions", "height", "head"};
      for (final field in node.nodes.keys.cast<YamlNode>()) {
        if (!known.contains(field.value)) {
          diagnostics.error(yamlSpan(file, field), "Unknown profile field '${field.value}'");
        }
      }

      final id = node.nodes["id"]?.value?.toString() ?? key;
      final previous = ids[id];
      if (previous != null) diagnostics.error(span, "Profiles '$previous' and '$key' share the id '$id'");
      ids[id] = key;

      final name = config.localizedFromYaml(file, node.nodes["name"], diagnostics, "name");
      if (name == null) diagnostics.error(span, "Profile '$key' has no name");

      final expressions = <String>[];
      final sprites = <String>[];
      final spriteSpans = <SourceSpan>[];
      final expressionsNode = node.nodes["expressions"];
      if (expressionsNode is YamlMap) {
        expressionsNode.nodes.forEach((nameNode, spriteNode) {
          final expression = (nameNode as YamlNode).value.toString();
          if (!_expressionPattern.hasMatch(expression)) {
            diagnostics.error(yamlSpan(file, nameNode), "Invalid expression name '$expression'");
          }
          expressions.add(expression);
          sprites.add(spriteNode.value?.toString() ?? "");
          spriteSpans.add(yamlSpan(file, spriteNode));
          if (spriteNode.value == null) diagnostics.error(yamlSpan(file, nameNode), "Expression '$expression' has no sprite");
        });
      } else if (expressionsNode != null && expressionsNode.value != null) {
        diagnostics.error(yamlSpan(file, expressionsNode), "'expressions' must map names to sprite files");
      }

      num? measure(String field) {
        final measured = node.nodes[field];
        if (measured == null || measured.value == null) return null;
        final value = measured.value;
        if (value is num && value > 0) return value;
        diagnostics.error(yamlSpan(file, measured), "'$field' must be a number above 0");
        return null;
      }

      ({num top, num chin})? head() {
        final headNode = node.nodes["head"];
        if (headNode == null || headNode.value == null) return null;
        if (headNode case YamlMap(
          value: {"top": final num top, "chin": final num chin},
        ) when headNode.length == 2 && 0 <= top && top < chin && chin <= 1) {
          return (top: top, chin: chin);
        }
        diagnostics.error(
          yamlSpan(file, headNode),
          "'head' must give 'top' and 'chin' as shares of the sprite height, top above chin: { top: 0.01, chin: 0.21 }",
        );
        return null;
      }

      final avatarNode = node.nodes["avatar"];
      profiles[key] = CastProfile(
        key: key,
        id: id,
        span: span,
        name: name,
        handle: node.nodes["handle"]?.value?.toString(),
        bio: config.localizedFromYaml(file, node.nodes["bio"], diagnostics, "bio"),
        avatar: avatarNode?.value?.toString(),
        avatarSpan: avatarNode == null ? null : yamlSpan(file, avatarNode),
        expressions: expressions,
        sprites: sprites,
        spriteSpans: spriteSpans,
        height: measure("height"),
        head: head(),
      );
    });
    return Cast(profiles);
  }
}

/// One `channels.yaml` entry: a chat thread (spec §1.3).
class ChannelDef {
  final String id;
  final SourceSpan span;
  final Localized? name;
  final String? avatar;
  final SourceSpan? avatarSpan;
  final Localized? status;
  final List<String> members;
  final List<SourceSpan> memberSpans;

  /// The character whose phone the thread is on (`owner:`), or null for the player's own threads.
  final String? owner;
  final SourceSpan? ownerSpan;

  const ChannelDef({
    required this.id,
    required this.span,
    required this.members,
    required this.memberSpans,
    this.name,
    this.avatar,
    this.avatarSpan,
    this.status,
    this.owner,
    this.ownerSpan,
  });

  static const fileName = "channels.yaml";

  static List<ChannelDef> parseAll(String source, StoryConfig config, Diagnostics diagnostics) {
    const file = fileName;
    final root = parseYaml(file, source, diagnostics);
    if (root == null || root.value == null) return const [];
    if (root is! YamlMap) {
      diagnostics.error(yamlSpan(file, root), "$fileName must map thread ids to threads");
      return const [];
    }
    final channels = <ChannelDef>[];
    root.nodes.forEach((keyNode, node) {
      final id = (keyNode as YamlNode).value.toString();
      final span = yamlSpan(file, keyNode);
      if (node is! YamlMap) {
        diagnostics.error(span, "Thread '$id' must be a map");
        return;
      }
      const known = {"name", "avatar", "status", "members", "owner"};
      for (final field in node.nodes.keys.cast<YamlNode>()) {
        if (!known.contains(field.value)) diagnostics.error(yamlSpan(file, field), "Unknown thread field '${field.value}'");
      }
      final name = config.localizedFromYaml(file, node.nodes["name"], diagnostics, "name");
      if (name == null) diagnostics.error(span, "Thread '$id' has no name");
      final membersNode = node.nodes["members"];
      final members = <String>[];
      final memberSpans = <SourceSpan>[];
      if (membersNode is YamlList) {
        for (final member in membersNode.nodes) {
          members.add(member.value.toString());
          memberSpans.add(yamlSpan(file, member));
        }
      } else if (membersNode != null && membersNode.value != null) {
        diagnostics.error(yamlSpan(file, membersNode), "'members' must be a list of character names");
      }
      final ownerNode = node.nodes["owner"];
      if (ownerNode != null && ownerNode.value is! String) {
        diagnostics.error(yamlSpan(file, ownerNode), "'owner' must be a character name");
      }
      final avatarNode = node.nodes["avatar"];
      channels.add(ChannelDef(
        id: id,
        span: span,
        name: name,
        avatar: avatarNode?.value?.toString(),
        avatarSpan: avatarNode == null ? null : yamlSpan(file, avatarNode),
        status: config.localizedFromYaml(file, node.nodes["status"], diagnostics, "status"),
        members: members,
        memberSpans: memberSpans,
        owner: ownerNode?.value is String ? ownerNode!.value as String : null,
        ownerSpan: ownerNode == null ? null : yamlSpan(file, ownerNode),
      ));
    });
    return channels;
  }
}

/// One clue in `clues.yaml` (spec §1.4).
class ClueDef {
  final String id;
  final SourceSpan span;
  final Localized? title;
  final Localized? description;
  final String? image;
  final SourceSpan? imageSpan;
  final bool key;
  final Localized? chapter;

  const ClueDef({
    required this.id,
    required this.span,
    this.title,
    this.description,
    this.image,
    this.imageSpan,
    this.key = false,
    this.chapter,
  });
}

/// `clues.yaml`: the Case Board's clues, in story order (spec §1.4, CE-05).
class ClueFile {
  static const fileName = "clues.yaml";
  static final _idPattern = RegExp(r"^[A-Za-z0-9_]+$");

  final bool showCounts;
  final List<ClueDef> clues;

  const ClueFile({this.showCounts = false, this.clues = const []});

  /// The clue declared as [id], if any.
  ClueDef? operator [](String id) => clues.where((clue) => clue.id == id).firstOrNull;

  static ClueFile parse(String source, StoryConfig config, Diagnostics diagnostics) {
    const file = fileName;
    final root = parseYaml(file, source, diagnostics);
    if (root == null || root.value == null) return const ClueFile();
    if (root is! YamlMap) {
      diagnostics.error(yamlSpan(file, root), "$fileName must be a map with 'clues'");
      return const ClueFile();
    }
    for (final field in root.nodes.keys.cast<YamlNode>()) {
      if (field.value != "clues" && field.value != "show_counts") {
        diagnostics.error(yamlSpan(file, field), "Unknown setting '${field.value}'. Clues go under 'clues'");
      }
    }
    final showCounts = root.nodes["show_counts"];
    if (showCounts != null && showCounts.value is! bool) {
      diagnostics.error(yamlSpan(file, showCounts), "'show_counts' must be true or false");
    }
    final cluesNode = root.nodes["clues"];
    final clues = <ClueDef>[];
    if (cluesNode is YamlMap) {
      cluesNode.nodes.forEach((keyNode, node) {
        final id = (keyNode as YamlNode).value.toString();
        final span = yamlSpan(file, keyNode);
        if (!_idPattern.hasMatch(id)) diagnostics.error(span, "Clue id '$id' can only use letters, digits and _");
        if (node is! YamlMap) {
          diagnostics.error(span, "Clue '$id' must be a map");
          return;
        }
        const known = {"title", "description", "image", "key", "chapter"};
        for (final field in node.nodes.keys.cast<YamlNode>()) {
          if (!known.contains(field.value)) {
            diagnostics.error(yamlSpan(file, field), "Unknown clue field '${field.value}'");
          }
        }
        final title = config.localizedFromYaml(file, node.nodes["title"], diagnostics, "title");
        if (title == null) diagnostics.error(span, "Clue '$id' has no title");
        final keyField = node.nodes["key"];
        if (keyField != null && keyField.value is! bool) {
          diagnostics.error(yamlSpan(file, keyField), "'key' must be true or false");
        }
        final imageNode = node.nodes["image"];
        clues.add(ClueDef(
          id: id,
          span: span,
          title: title,
          description: config.localizedFromYaml(file, node.nodes["description"], diagnostics, "description"),
          image: imageNode?.value?.toString(),
          imageSpan: imageNode == null ? null : yamlSpan(file, imageNode),
          key: keyField?.value == true,
          chapter: config.localizedFromYaml(file, node.nodes["chapter"], diagnostics, "chapter"),
        ));
      });
    } else if (cluesNode != null && cluesNode.value != null) {
      diagnostics.error(yamlSpan(file, cluesNode), "'clues' must map clue ids to clues");
    }
    return ClueFile(showCounts: showCounts?.value == true, clues: clues);
  }
}
