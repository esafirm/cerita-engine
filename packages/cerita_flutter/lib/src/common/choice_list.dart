import 'package:cerita_core/cerita_core.dart';
import 'package:flutter/material.dart';

import '../skin/story_skin.dart';

/// Choice buttons with an optional countdown bar (`timeout_ms`) and locked
/// (condition-failing) options shown disabled with a lock icon.
class ChoiceList extends StatefulWidget {
  final ChoiceItemType item;
  final ValueChanged<Choice> onSelected;
  final bool dark;

  const ChoiceList({super.key, required this.item, required this.onSelected, this.dark = false});

  @override
  State<ChoiceList> createState() => _ChoiceListState();
}

class _ChoiceListState extends State<ChoiceList> with SingleTickerProviderStateMixin {
  AnimationController? _countdown;

  @override
  void initState() {
    super.initState();
    final timeout = widget.item.timeoutMs;
    if (timeout != null && timeout > 0) {
      _countdown = AnimationController(vsync: this, duration: Duration(milliseconds: timeout))
        ..addStatusListener((status) {
          final fallback = widget.item.timeoutChoice;
          if (status == AnimationStatus.completed && fallback != null) widget.onSelected(fallback);
        })
        ..forward();
    }
  }

  @override
  void dispose() {
    _countdown?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final countdown = _countdown;
    final skin = StorySkin.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (countdown != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AnimatedBuilder(
              animation: countdown,
              builder: (context, _) {
                final remaining = (widget.item.timeoutMs! * (1 - countdown.value) / 1000).ceil();
                return Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 16, color: scheme.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: 1 - countdown.value,
                          minHeight: 6,
                          color: scheme.error,
                          backgroundColor: scheme.errorContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text("${remaining}s", style: TextStyle(color: widget.dark ? Colors.white : scheme.error)),
                  ],
                );
              },
            ),
          ),
        for (final (index, choice) in widget.item.choices.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: skin.choiceButton(
              context,
              choice,
              index,
              choice.locked
                  ? null
                  : () {
                      _countdown?.stop();
                      widget.onSelected(choice);
                    },
              dark: widget.dark,
            ),
          ),
      ],
    );
  }
}
