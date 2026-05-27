import 'package:flutter/material.dart';

import '../application/calculator_state.dart';

class AiResultPanel extends StatelessWidget {
  const AiResultPanel({
    super.key,
    required this.state,
  });

  final CalculatorState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusText = switch (state.status) {
      CalculatorStatus.modelLoading => 'Загрузка модели...',
      CalculatorStatus.generating => 'AI думает...',
      CalculatorStatus.error => 'Ошибка',
      CalculatorStatus.ready => 'Готово',
      CalculatorStatus.idle => 'Ожидание',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Статус: $statusText',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (state.status == CalculatorStatus.generating)
                const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            state.aiText.isEmpty ? 'Ожидаю задачу...' : state.aiText,
            style: TextStyle(color: scheme.onSurface, fontSize: 15),
          ),
          const SizedBox(height: 8),
          if (state.confidence != null || state.mood != null)
            Text(
              'confidence: ${state.confidence?.toStringAsFixed(2) ?? '-'} | mood: ${state.mood ?? '-'}',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}
