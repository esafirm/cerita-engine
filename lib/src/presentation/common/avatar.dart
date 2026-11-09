import 'package:flutter/material.dart';

/// Circular avatar from an asset path, falling back to the first letter of [name].
class StoryAvatar extends StatelessWidget {
  final String? asset;
  final String name;
  final double radius;

  const StoryAvatar({super.key, required this.asset, required this.name, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundImage: asset == null ? null : AssetImage(asset!),
      child: Text(name.isEmpty ? "?" : name.characters.first, style: TextStyle(fontSize: radius * 0.8)),
    );
  }
}
