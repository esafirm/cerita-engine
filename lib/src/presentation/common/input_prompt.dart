import 'package:flutter/material.dart';
import 'package:fsse/fsse.dart';

/// Text field + confirm button for INPUT items. Empty input falls back to `default_value`.
class InputPrompt extends StatefulWidget {
  final InputItemType item;
  final ValueChanged<String> onSubmit;
  final bool showPrompt;

  const InputPrompt({super.key, required this.item, required this.onSubmit, this.showPrompt = true});

  @override
  State<InputPrompt> createState() => _InputPromptState();
}

class _InputPromptState extends State<InputPrompt> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => widget.onSubmit(_controller.text);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showPrompt)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(widget.item.text, style: Theme.of(context).textTheme.titleMedium),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: widget.item.defaultValue ?? "Type here",
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _submit, icon: const Icon(Icons.send)),
          ],
        ),
      ],
    );
  }
}
