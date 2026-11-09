import 'package:flutter/material.dart';
import 'package:fsse/fsse.dart';

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
        for (final choice in widget.item.choices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _ChoiceButton(
              choice: choice,
              dark: widget.dark,
              onTap: choice.locked
                  ? null
                  : () {
                      _countdown?.stop();
                      widget.onSelected(choice);
                    },
            ),
          ),
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final Choice choice;
  final VoidCallback? onTap;
  final bool dark;

  const _ChoiceButton({required this.choice, required this.onTap, required this.dark});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = dark ? Colors.black.withAlpha(150) : scheme.surfaceContainerHighest;
    final foreground = dark ? Colors.white : scheme.onSurface;
    return Material(
      color: choice.locked ? background.withAlpha(90) : background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: choice.locked ? Colors.transparent : scheme.primary.withAlpha(140)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (choice.locked) ...[
                Icon(Icons.lock_outline, size: 18, color: foreground.withAlpha(120)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  choice.text,
                  style: TextStyle(color: choice.locked ? foreground.withAlpha(120) : foreground, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
