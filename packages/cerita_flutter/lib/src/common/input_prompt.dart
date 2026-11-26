import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/story_language.dart';
import 'tagged_text.dart';

/// Text field + confirm button for INPUT items. Empty input falls back to `default_value`.
///
/// The item's `keyboard`, `min_length` and `max_length` pick the keyboard and limit what can be typed. The
/// button stays disabled until the answer is long enough ([InputItemType.accepts]).
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
  void didUpdateWidget(InputPrompt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit => widget.item.accepts(_controller.text.trim());

  void _submit() {
    if (_canSubmit) widget.onSubmit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final digits = item.keyboard == InputKeyboard.digits;
    final strings = StoryLanguage.of(context).strings;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showPrompt)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TaggedText(item.text, style: Theme.of(context).textTheme.titleMedium),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: digits ? TextInputType.number : TextInputType.text,
                inputFormatters: [
                  if (digits) FilteringTextInputFormatter.digitsOnly,
                  if (item.maxLength != null) LengthLimitingTextInputFormatter(item.maxLength),
                ],
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                // Keep the keyboard up when the answer can't be sent yet.
                onEditingComplete: () {},
                decoration: InputDecoration(
                  hintText: item.defaultValue ?? strings.typeHere,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, _, _) => IconButton.filled(
                tooltip: strings.send,
                onPressed: _canSubmit ? _submit : null,
                icon: const Icon(Icons.send),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
