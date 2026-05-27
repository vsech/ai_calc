import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../llm/infrastructure/model_manager.dart';
import '../application/calculator_controller.dart';
import '../application/calculator_state.dart';
import '../application/providers.dart';
import '../domain/ai_calculator_mode.dart';
import '../domain/calculator_interface_mode.dart';
import 'ai_result_panel.dart';
import 'calculator_keypad.dart';

const _recommendedModelDownloads = <_RecommendedModelDownload>[
  _RecommendedModelDownload(
    label: 'Qwen2.5 0.5B Instruct Q4_K_M',
    details: '491 MB, fast start',
    url: CalculatorController.liteDefaultModelUrl,
  ),
  _RecommendedModelDownload(
    label: 'TinyLlama 1.1B Chat Q4_K_M',
    details: '668 MB, Llama architecture',
    url:
        'https://huggingface.co/hieupt/TinyLlama-1.1B-Chat-v1.0-Q4_K_M-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0-q4_k_m.gguf',
  ),
  _RecommendedModelDownload(
    label: 'Qwen2.5 1.5B Instruct Q4_K_M',
    details: '1.07 GB, better quality',
    url:
        'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
  ),
];

const _customModelDownload = _RecommendedModelDownload(
  label: 'Custom URL',
  details: 'manual URL',
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
      appBar: AppBar(
        title: const Text('AI Calculator'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => _showSettingsDialog(
              context,
              selected: state.interfaceMode,
              onChanged: controller.setInterfaceMode,
            ),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: state.interfaceMode == CalculatorInterfaceMode.lite
              ? _LiteCalculatorView(
                  state: state,
                  controller: controller,
                  onDownloadDefaultModel: () =>
                      _confirmLiteModelDownload(context, controller),
                )
              : _AdvancedCalculatorView(
                  state: state,
                  controller: controller,
                  onDownloadModel: () async {
                    final url = await _showModelUrlDialog(context);
                    if (url != null && url.isNotEmpty) {
                      await controller.downloadModelFromUrl(url);
                    }
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _showSettingsDialog(
    BuildContext context, {
    required CalculatorInterfaceMode selected,
    required Future<void> Function(CalculatorInterfaceMode mode) onChanged,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Settings'),
          content: SizedBox(
            width: double.maxFinite,
            child: SegmentedButton<CalculatorInterfaceMode>(
              segments: [
                for (final mode in CalculatorInterfaceMode.values)
                  ButtonSegment<CalculatorInterfaceMode>(
                    value: mode,
                    label: Text(mode.label),
                  ),
              ],
              selected: <CalculatorInterfaceMode>{selected},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                if (selection.isEmpty) {
                  return;
                }
                unawaited(onChanged(selection.first));
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmLiteModelDownload(
    BuildContext context,
    CalculatorController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Download model?'),
          content: const Text(
            'Lite needs a small local GGUF model. Download Qwen2.5 0.5B '
            'Instruct Q4_K_M, about 491 MB?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Download'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await controller.downloadLiteDefaultModel();
    }
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
              title: const Text('Download GGUF model'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<_RecommendedModelDownload>(
                      initialValue: selectedModel,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Model'),
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
                          child: Text('Custom URL · manual URL'),
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
                        labelText: 'Model URL',
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
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(urlController.text.trim()),
                  child: const Text('Download'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(urlController.dispose);
  }
}

class _LiteCalculatorView extends StatelessWidget {
  const _LiteCalculatorView({
    required this.state,
    required this.controller,
    required this.onDownloadDefaultModel,
  });

  final CalculatorState state;
  final CalculatorController controller;
  final Future<void> Function() onDownloadDefaultModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ExpressionPanel(
          expression: state.expression,
          result: null,
          errorMessage: null,
          showResult: false,
        ),
        const SizedBox(height: 12),
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
                _LiteAnswerPanel(
                  state: state,
                  onDownloadDefaultModel: onDownloadDefaultModel,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AdvancedCalculatorView extends StatelessWidget {
  const _AdvancedCalculatorView({
    required this.state,
    required this.controller,
    required this.onDownloadModel,
  });

  final CalculatorState state;
  final CalculatorController controller;
  final Future<void> Function() onDownloadModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ExpressionPanel(
          expression: state.expression,
          result: state.result,
          errorMessage: state.errorMessage,
        ),
        const SizedBox(height: 10),
        _ModeSelector(selected: state.mode, onChanged: controller.setMode),
        const SizedBox(height: 10),
        _ModelStatus(
          model: state.model,
          isDownloading: state.isModelDownloading,
          progress: state.modelDownloadProgress,
          onSelectModel: controller.chooseModel,
          onResetModel: controller.resetModel,
          onDownloadModel: onDownloadModel,
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
    );
  }
}

class _LiteAnswerPanel extends StatelessWidget {
  const _LiteAnswerPanel({
    required this.state,
    required this.onDownloadDefaultModel,
  });

  final CalculatorState state;
  final Future<void> Function() onDownloadDefaultModel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isBusy =
        state.status == CalculatorStatus.modelLoading ||
        state.status == CalculatorStatus.generating ||
        state.isModelDownloading;
    final needsModel = state.model == null || !state.isLlmInitialized;

    Widget child;
    if (isBusy) {
      child = const Row(
        children: [
          SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Думаю...'),
        ],
      );
    } else if (needsModel) {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Нужна маленькая модель',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lite работает локально через Qwen2.5 0.5B Instruct Q4_K_M.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onDownloadDefaultModel,
            icon: const Icon(Icons.download),
            label: const Text('Скачать модель'),
          ),
        ],
      );
    } else if (state.errorMessage != null) {
      child = Text(state.errorMessage!, style: TextStyle(color: scheme.error));
    } else {
      child = Text(
        state.result ?? 'Введите выражение',
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: state.result == null ? 16 : 28,
          fontWeight: state.result == null ? FontWeight.w400 : FontWeight.w700,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _ExpressionPanel extends StatelessWidget {
  const _ExpressionPanel({
    required this.expression,
    required this.result,
    required this.errorMessage,
    this.showResult = true,
  });

  final String expression;
  final String? result;
  final String? errorMessage;
  final bool showResult;

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
          if (showResult) ...[
            const SizedBox(height: 8),
            Text(
              'Result: ${result ?? '-'}',
              style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
            ),
          ],
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
