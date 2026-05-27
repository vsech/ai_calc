import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/errors/expression_evaluation_exception.dart';
import '../../../shared/errors/llm_service_exception.dart';
import '../../llm/application/llm_service.dart';
import '../../llm/application/prompt_builder.dart';
import '../../llm/infrastructure/model_manager.dart';
import '../domain/ai_calculator_mode.dart';
import '../domain/ai_calculator_result.dart';
import '../domain/calculator_interface_mode.dart';
import '../domain/expression_evaluator.dart';
import 'calculator_state.dart';
import 'dependency_providers.dart';

class CalculatorController extends Notifier<CalculatorState> {
  late final ExpressionEvaluator _expressionEvaluator;
  late final LlmService _llmService;
  late final PromptBuilder _promptBuilder;
  late final ModelManager _modelManager;

  final Random _random = Random();
  StreamSubscription<String>? _streamSubscription;

  static const _modelRequiredMessage =
      'Модель не загружена. Выберите или скачайте GGUF.';
  static const liteDefaultModelUrl =
      'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const _interfaceModeKey = 'calculator_interface_mode';

  static const _aiResultJsonGrammar = r'''
root ::= object
object ::= "{" ws short-answer ws "," ws explanation ws "," ws confidence ws "," ws mood ws "}"
short-answer ::= "\"short_answer\"" ws ":" ws string
explanation ::= "\"explanation\"" ws ":" ws string
confidence ::= "\"confidence\"" ws ":" ws number
mood ::= "\"mood\"" ws ":" ws string
string ::= "\"" chars "\""
chars ::= ([^"\\] | "\\" ["\\/bfnrt] | "\\u" hex hex hex hex)*
number ::= "-"? ("0" | [1-9] [0-9]*) ("." [0-9]+)?
hex ::= [0-9a-fA-F]
ws ::= [ \t\n\r]*
''';

  @override
  CalculatorState build() {
    _expressionEvaluator = ref.read(expressionEvaluatorProvider);
    _llmService = ref.read(llmServiceProvider);
    _promptBuilder = ref.read(promptBuilderProvider);
    _modelManager = ref.read(modelManagerProvider);

    unawaited(Future<void>.microtask(_bootstrap));
    ref.onDispose(() {
      unawaited(_streamSubscription?.cancel());
      unawaited(_llmService.dispose());
    });
    return CalculatorState.initial();
  }

  void appendToken(String token) {
    state = state.copyWith(
      expression: state.expression + token,
      clearError: true,
    );
  }

  void backspace() {
    if (state.expression.isEmpty) {
      return;
    }
    state = state.copyWith(
      expression: state.expression.substring(0, state.expression.length - 1),
      clearError: true,
    );
  }

  void clearExpression() {
    state = state.copyWith(
      expression: '',
      clearResult: true,
      aiText: '',
      clearConfidence: true,
      clearMood: true,
      clearError: true,
    );
  }

  void setMode(AiCalculatorMode mode) {
    state = state.copyWith(mode: mode, clearError: true);
  }

  Future<void> setInterfaceMode(CalculatorInterfaceMode mode) async {
    state = state.copyWith(interfaceMode: mode, clearError: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_interfaceModeKey, mode.wireName);
  }

  Future<void> downloadLiteDefaultModel() {
    return downloadModelFromUrl(liteDefaultModelUrl);
  }

  Future<void> chooseModel() async {
    state = state.copyWith(
      status: CalculatorStatus.modelLoading,
      clearError: true,
      clearModelDownloadProgress: true,
      isModelDownloading: false,
      isLlmInitialized: false,
    );
    try {
      final model = await _modelManager.chooseModel();
      if (model == null) {
        state = state.copyWith(
          status: CalculatorStatus.ready,
          errorMessage: 'Выбор модели отменен.',
        );
        return;
      }
      final validation = await _modelManager.validateModel(model);
      if (!validation.isValid) {
        state = state.copyWith(
          status: CalculatorStatus.error,
          errorMessage: validation.message ?? 'Модель не прошла проверку.',
        );
        return;
      }
      state = state.copyWith(model: model);
      await _initializeLlm(model.modelRef);
    } on ModelDownloadException catch (error) {
      state = state.copyWith(
        status: CalculatorStatus.error,
        errorMessage: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: CalculatorStatus.error,
        errorMessage: 'Не удалось выбрать модель.',
      );
    }
  }

  Future<void> downloadModelFromUrl(String url) async {
    if (url.trim().isEmpty) {
      state = state.copyWith(
        status: CalculatorStatus.error,
        errorMessage: 'Введите ссылку на GGUF модель.',
      );
      return;
    }

    state = state.copyWith(
      status: CalculatorStatus.modelLoading,
      clearError: true,
      isModelDownloading: true,
      modelDownloadProgress: 0,
      isLlmInitialized: false,
    );

    try {
      final model = await _modelManager.downloadModel(
        url: url,
        onProgress: (progress) {
          state = state.copyWith(
            isModelDownloading: true,
            modelDownloadProgress: progress.clamp(0.0, 1.0),
          );
        },
      );
      final validation = await _modelManager.validateModel(model);
      if (!validation.isValid) {
        state = state.copyWith(
          status: CalculatorStatus.error,
          isModelDownloading: false,
          clearModelDownloadProgress: true,
          errorMessage:
              validation.message ?? 'Загруженная модель не прошла проверку.',
        );
        return;
      }
      state = state.copyWith(
        model: model,
        modelDownloadProgress: 1,
        isModelDownloading: false,
      );
      await _initializeLlm(model.modelRef);
    } on ModelDownloadException catch (error) {
      state = state.copyWith(
        status: CalculatorStatus.error,
        isModelDownloading: false,
        clearModelDownloadProgress: true,
        errorMessage: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: CalculatorStatus.error,
        isModelDownloading: false,
        clearModelDownloadProgress: true,
        errorMessage: 'Ошибка загрузки модели.',
      );
    }
  }

  Future<void> resetModel() async {
    await _modelManager.resetModel();
    await _llmService.dispose();
    state = state.copyWith(
      clearModel: true,
      status: CalculatorStatus.ready,
      isModelDownloading: false,
      clearModelDownloadProgress: true,
      isLlmInitialized: false,
      errorMessage: _modelRequiredMessage,
    );
  }

  Future<void> evaluateAndExplain() async {
    await _streamSubscription?.cancel();
    final useGeneratedAnswer =
        state.interfaceMode == CalculatorInterfaceMode.lite;
    state = state.copyWith(
      status: CalculatorStatus.generating,
      aiText: '',
      clearResult: useGeneratedAnswer,
      clearError: true,
      clearConfidence: true,
      clearMood: true,
    );

    try {
      final correctValue = _expressionEvaluator.evaluate(state.expression);
      final correctResult = _formatNumber(correctValue);
      final shownResult = _applyModeResult(correctValue, state.mode);
      if (!useGeneratedAnswer) {
        state = state.copyWith(result: _formatNumber(shownResult));
      }

      if (state.model == null || !state.isLlmInitialized) {
        state = state.copyWith(
          status: CalculatorStatus.error,
          errorMessage: _modelRequiredMessage,
        );
        return;
      }

      final prompt = _promptBuilder.buildPrompt(
        expression: state.expression,
        correctResult: correctResult,
        mode: state.mode,
      );

      final buffer = StringBuffer();
      final completer = Completer<void>();

      _streamSubscription = _llmService
          .generate(
            prompt: prompt,
            maxTokens: 160,
            temperature: 0,
            grammar: _aiResultJsonGrammar,
            stopSequences: const ['```', '\n\nUSER:', '\n\nSYSTEM:'],
          )
          .listen(
            (chunk) {
              buffer.write(chunk);
              if (!useGeneratedAnswer) {
                state = state.copyWith(aiText: buffer.toString());
              }
            },
            onError: (Object error, StackTrace _) {
              state = state.copyWith(
                status: CalculatorStatus.error,
                errorMessage: _humanizeError(error),
              );
              if (!completer.isCompleted) {
                completer.complete();
              }
            },
            onDone: () {
              final parsed = _parseAiResponse(buffer.toString());
              if (parsed == null) {
                state = state.copyWith(
                  status: CalculatorStatus.error,
                  errorMessage: 'Модель вернула невалидный JSON.',
                );
              } else {
                _applyAiResult(parsed, useGeneratedAnswer: useGeneratedAnswer);
                state = state.copyWith(status: CalculatorStatus.ready);
              }
              if (!completer.isCompleted) {
                completer.complete();
              }
            },
            cancelOnError: true,
          );

      await completer.future;
    } on ExpressionEvaluationException catch (error) {
      state = state.copyWith(
        status: CalculatorStatus.error,
        errorMessage: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: CalculatorStatus.error,
        errorMessage: 'Не удалось обработать выражение.',
      );
    }
  }

  Future<void> _bootstrap() async {
    await _loadInterfaceMode();
    state = state.copyWith(status: CalculatorStatus.modelLoading);
    final savedModel = await _modelManager.loadSavedModel();

    if (savedModel == null) {
      state = state.copyWith(
        status: CalculatorStatus.ready,
        isLlmInitialized: false,
        isModelDownloading: false,
        clearModelDownloadProgress: true,
        errorMessage: _modelRequiredMessage,
      );
      return;
    }

    final validation = await _modelManager.validateModel(savedModel);
    if (!validation.isValid) {
      state = state.copyWith(
        status: CalculatorStatus.error,
        isLlmInitialized: false,
        errorMessage: validation.message ?? _modelRequiredMessage,
      );
      return;
    }

    state = state.copyWith(model: savedModel);
    await _initializeLlm(savedModel.modelRef);
  }

  Future<void> _loadInterfaceMode() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      interfaceMode: CalculatorInterfaceMode.fromWireName(
        prefs.getString(_interfaceModeKey),
      ),
    );
  }

  Future<void> _initializeLlm(String modelRef) async {
    try {
      await _llmService.initialize(modelPath: modelRef);
      state = state.copyWith(
        status: CalculatorStatus.ready,
        isLlmInitialized: true,
        isModelDownloading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        status: CalculatorStatus.error,
        isLlmInitialized: false,
        isModelDownloading: false,
        errorMessage: _humanizeError(error),
      );
    }
  }

  double _applyModeResult(double correctValue, AiCalculatorMode mode) {
    if (mode != AiCalculatorMode.chaoticAi) {
      return correctValue;
    }
    const offsets = <int>[-9, -7, -4, -3, -2, -1, 1, 2, 3, 4, 7, 9];
    return correctValue + offsets[_random.nextInt(offsets.length)];
  }

  AiCalculatorResult? _parseAiResponse(String rawResponse) {
    final decoded = _decodeAiResponseJson(rawResponse);
    if (decoded == null) {
      return null;
    }

    final shortAnswer = decoded['short_answer']?.toString();
    final explanation = decoded['explanation']?.toString();
    final mood = decoded['mood']?.toString();
    final confidence = (decoded['confidence'] is num)
        ? (decoded['confidence'] as num).toDouble()
        : null;

    if (shortAnswer == null ||
        explanation == null ||
        mood == null ||
        confidence == null) {
      return null;
    }

    return AiCalculatorResult(
      shortAnswer: shortAnswer,
      explanation: explanation,
      confidence: confidence,
      mood: mood,
      source: AiResultSource.llm,
    );
  }

  Map<String, dynamic>? _decodeAiResponseJson(String rawResponse) {
    final candidates = <String>[
      rawResponse.trim(),
      ?_extractFirstJsonObject(rawResponse),
    ];

    for (final candidate in candidates) {
      if (candidate.isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  String? _extractFirstJsonObject(String text) {
    var depth = 0;
    var start = -1;
    var inString = false;
    var escaped = false;

    for (var i = 0; i < text.length; i += 1) {
      final char = text[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }

      if (char == '"') {
        inString = true;
      } else if (char == '{') {
        if (depth == 0) {
          start = i;
        }
        depth += 1;
      } else if (char == '}') {
        if (depth == 0) {
          continue;
        }
        depth -= 1;
        if (depth == 0 && start >= 0) {
          return text.substring(start, i + 1);
        }
      }
    }

    return null;
  }

  void _applyAiResult(
    AiCalculatorResult result, {
    required bool useGeneratedAnswer,
  }) {
    state = state.copyWith(
      result: useGeneratedAnswer ? result.explanation : null,
      aiText: result.explanation,
      confidence: result.confidence,
      mood: result.mood,
    );
  }

  String _humanizeError(Object error) {
    if (error is LlmServiceException) {
      return error.message;
    }
    if (error is ModelDownloadException) {
      return error.message;
    }
    return 'Сбой LLM операции.';
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value
        .toStringAsFixed(8)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
