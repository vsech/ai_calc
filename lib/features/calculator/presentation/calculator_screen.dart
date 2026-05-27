import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../llm/infrastructure/model_manager.dart';
import '../application/providers.dart';
import '../domain/ai_calculator_mode.dart';
import 'ai_result_panel.dart';
import 'calculator_keypad.dart';

const _recommendedModelDownloads = <_RecommendedModelDownload>[
  _RecommendedModelDownload(
    label: 'Qwen2.5 0.5B Instruct Q4_K_M',
    details: '491 MB, быстрый старт',
    url:
        'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
  ),
  _RecommendedModelDownload(
    label: 'TinyLlama 1.1B Chat Q4_K_M',
    details: '668 MB, Llama-архитектура',
    url:
        'https://huggingface.co/hieupt/TinyLlama-1.1B-Chat-v1.0-Q4_K_M-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0-q4_k_m.gguf',
  ),
  _RecommendedModelDownload(
    label: 'Qwen2.5 1.5B Instruct Q4_K_M',
    details: '1.07 GB, лучше качество',
    url:
        'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
  ),
];

const _customModelDownload = _RecommendedModelDownload(
  label: 'Своя ссылка',
  details: 'ручной URL',
  url: '',
);

class _RecommendedModelDownload {
  const _RecommendedModelDownload({
    required this.label,
    required this.details,
    required this.url,
  });

  final String label;
  final String details;
  final String url;
}

class CalculatorScreen extends ConsumerWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calculatorControllerProvider);
    final controller = ref.read(calculatorControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Calculator / НейроКалькулятор')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ExpressionPanel(
                expression: state.expression,
                result: state.result,
                errorMessage: state.errorMessage,
              ),
              const SizedBox(height: 10),
              _ModeSelector(
                selected: state.mode,
                onChanged: controller.setMode,
              ),
              const SizedBox(height: 10),
              _ModelStatus(
                model: state.model,
                isDownloading: state.isModelDownloading,
                progress: state.modelDownloadProgress,
                onSelectModel: controller.chooseModel,
                onResetModel: controller.resetModel,
                onDownloadModel: () async {
                  final url = await _showModelUrlDialog(context);
                  if (url != null && url.isNotEmpty) {
                    await controller.downloadModelFromUrl(url);
                  }
                },
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      CalculatorKeypad(
                        onTap: controller.appendToken,
                        onBackspace: controller.backspace,
                        onClear: controller.clearExpression,
                        onEquals: controller.evaluateAndExplain,
                      ),
                      const SizedBox(height: 12),
                      AiResultPanel(state: state),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showModelUrlDialog(BuildContext context) {
    final urlController = TextEditingController(
      text: _recommendedModelDownloads.first.url,
    );
    var selectedModel = _recommendedModelDownloads.first;

    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Скачать GGUF модель'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<_RecommendedModelDownload>(
                      initialValue: selectedModel,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Модель'),
                      items: [
                        for (final model in _recommendedModelDownloads)
                          DropdownMenuItem<_RecommendedModelDownload>(
                            value: model,
                            child: Text(
                              '${model.label} · ${model.details}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const DropdownMenuItem<_RecommendedModelDownload>(
                          value: _customModelDownload,
                          child: Text('Своя ссылка · ручной URL'),
                        ),
                      ],
                      onChanged: (model) {
                        if (model == null) {
                          return;
                        }
                        setState(() {
                          selectedModel = model;
                          if (model.url.isEmpty) {
                            urlController.clear();
                          } else {
                            urlController.text = model.url;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlController,
                      decoration: const InputDecoration(
                        labelText: 'URL модели',
                        hintText: 'https://.../model.gguf',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(urlController.text.trim()),
                  child: const Text('Скачать'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(urlController.dispose);
  }
}

class _ExpressionPanel extends StatelessWidget {
  const _ExpressionPanel({
    required this.expression,
    required this.result,
    required this.errorMessage,
  });

  final String expression;
  final String? result;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          Text(
            expression.isEmpty ? 'Введите выражение' : expression,
            style: const TextStyle(fontSize: 22),
          ),
          const SizedBox(height: 8),
          Text(
            'Result: ${result ?? '-'}',
            style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: TextStyle(color: scheme.error, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selected, required this.onChanged});

  final AiCalculatorMode selected;
  final ValueChanged<AiCalculatorMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<AiCalculatorMode>(
        segments: [
          for (final mode in AiCalculatorMode.values)
            ButtonSegment<AiCalculatorMode>(
              value: mode,
              label: Text(mode.label),
            ),
        ],
        selected: <AiCalculatorMode>{selected},
        showSelectedIcon: false,
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) {
            onChanged(selection.first);
          }
        },
      ),
    );
  }
}

class _ModelStatus extends StatelessWidget {
  const _ModelStatus({
    required this.model,
    required this.isDownloading,
    required this.progress,
    required this.onSelectModel,
    required this.onResetModel,
    required this.onDownloadModel,
  });

  final ModelDescriptor? model;
  final bool isDownloading;
  final double? progress;
  final VoidCallback onSelectModel;
  final VoidCallback onResetModel;
  final VoidCallback onDownloadModel;

  @override
  Widget build(BuildContext context) {
    final name = model?.fileName ?? 'не выбрана';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'GGUF модель: $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Скачать модель',
              onPressed: isDownloading ? null : onDownloadModel,
              icon: const Icon(Icons.download),
            ),
            IconButton(
              tooltip: 'Выбрать GGUF',
              onPressed: isDownloading ? null : onSelectModel,
              icon: const Icon(Icons.folder_open),
            ),
            IconButton(
              tooltip: 'Сбросить модель',
              onPressed: isDownloading ? null : onResetModel,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (isDownloading) ...[
          const SizedBox(height: 6),
          LinearProgressIndicator(value: progress),
        ],
      ],
    );
  }
}
