import 'dart:developer' as developer;

import 'package:flutter/material.dart';

/// [Poi] handles the actor image and background image
class Poi extends StatelessWidget {
  final String? _background;
  final String? _actor;

  const Poi(this._background, this._actor, {super.key});

  @override
  Widget build(BuildContext context) {
    developer.log("Return image content");

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_background != null) Image.asset(_background!, fit: BoxFit.fitWidth),
        if (_actor != null)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Image.asset(_actor!, fit: BoxFit.fitHeight),
          ),
      ],
    );
  }
}

