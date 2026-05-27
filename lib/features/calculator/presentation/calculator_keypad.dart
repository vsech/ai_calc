import 'package:flutter/material.dart';

class CalculatorKeypad extends StatelessWidget {
  const CalculatorKeypad({
    super.key,
    required this.onTap,
    required this.onBackspace,
    required this.onClear,
    required this.onEquals,
  });

  final ValueChanged<String> onTap;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onEquals;

  @override
  Widget build(BuildContext context) {
    const rows = <List<_KeyData>>[
      <_KeyData>[
        _KeyData.clear(),
        _KeyData.backspace(),
        _KeyData.input('('),
        _KeyData.input(')'),
      ],
      <_KeyData>[
        _KeyData.input('7'),
        _KeyData.input('8'),
        _KeyData.input('9'),
        _KeyData.input('/', label: '÷'),
      ],
      <_KeyData>[
        _KeyData.input('4'),
        _KeyData.input('5'),
        _KeyData.input('6'),
        _KeyData.input('*', label: '×'),
      ],
      <_KeyData>[
        _KeyData.input('1'),
        _KeyData.input('2'),
        _KeyData.input('3'),
        _KeyData.input('-', label: '−'),
      ],
      <_KeyData>[
        _KeyData.input('0'),
        _KeyData.input('.', label: ','),
        _KeyData.equals(),
        _KeyData.input('+'),
      ],
    ];

    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _KeyButton(
                        label: key.label,
                        icon: key.icon,
                        tooltip: key.tooltip,
                        emphasized: key.action == _KeyAction.equals,
                        onPressed: _callbackFor(key),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  VoidCallback _callbackFor(_KeyData key) {
    switch (key.action) {
      case _KeyAction.input:
        return () => onTap(key.value);
      case _KeyAction.backspace:
        return onBackspace;
      case _KeyAction.clear:
        return onClear;
      case _KeyAction.equals:
        return onEquals;
    }
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.tooltip,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final String? tooltip;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: Tooltip(
        message: tooltip ?? label,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: emphasized
                ? scheme.primary
                : scheme.surfaceContainerHighest,
            foregroundColor: emphasized ? scheme.onPrimary : scheme.onSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(fontSize: 18),
          ),
          onPressed: onPressed,
          child: icon == null
              ? Text(label)
              : Icon(icon, size: 20, semanticLabel: tooltip ?? label),
        ),
      ),
    );
  }
}

enum _KeyAction { input, backspace, clear, equals }

class _KeyData {
  const _KeyData.input(this.value, {String? label})
    : action = _KeyAction.input,
      label = label ?? value,
      icon = null,
      tooltip = null;

  const _KeyData.backspace()
    : action = _KeyAction.backspace,
      value = '',
      label = 'Backspace',
      icon = Icons.backspace,
      tooltip = 'Backspace';

  const _KeyData.clear()
    : action = _KeyAction.clear,
      value = '',
      label = 'AC',
      icon = null,
      tooltip = 'Clear';

  const _KeyData.equals()
    : action = _KeyAction.equals,
      value = '',
      label = '=',
      icon = null,
      tooltip = null;

  final _KeyAction action;
  final String value;
  final String label;
  final IconData? icon;
  final String? tooltip;
}
