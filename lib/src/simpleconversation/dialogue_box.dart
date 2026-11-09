import 'package:flutter/material.dart';

class DialogueBox extends StatelessWidget {
  final String _text;

  const DialogueBox(this._text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(160),
        border: Border.all(color: Colors.blue, width: 2),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Text(
        _text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      ),
    );
  }
}

