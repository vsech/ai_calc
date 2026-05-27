import 'package:llamadart/llamadart.dart';

import '../../../shared/errors/llm_service_exception.dart';
import '../application/llm_service.dart';

class LlamaCppLlmService implements LlmService {
  factory LlamaCppLlmService({
    LlamaEngine? engine,
    LlamaEngine Function()? engineFactory,
  }) {
    return LlamaCppLlmService._(
      engine,
      engineFactory ?? () => LlamaEngine(LlamaBackend()),
    );
  }

  LlamaCppLlmService._(this._engine, this._engineFactory);

  final LlamaEngine Function() _engineFactory;
  LlamaEngine? _engine;
  bool _isInitialized = false;

  LlamaEngine get _activeEngine => _engine ??= _engineFactory();

  @override
  Future<void> initialize({required String modelPath}) async {
    if (modelPath.isEmpty) {
      throw const LlmServiceException(
        LlmServiceErrorCode.initializationFailed,
        'Путь к модели пустой.',
      );
    }
    if (modelPath.toLowerCase().startsWith('content://')) {
      throw const LlmServiceException(
        LlmServiceErrorCode.initializationFailed,
        'content:// URI не поддерживается llama.cpp напрямую. Скачайте модель в локальное хранилище приложения.',
      );
    }

    try {
      final engine = _activeEngine;
      if (engine.isReady) {
        await engine.unloadModel();
      }

      await engine.loadModel(
        modelPath,
        modelParams: const ModelParams(
          numberOfThreads: 4,
          gpuLayers: 0,
          contextSize: 2048,
          batchSize: 512,
        ),
      );
      _isInitialized = true;
    } on LlmServiceException {
      rethrow;
    } catch (error) {
      throw LlmServiceException(
        LlmServiceErrorCode.initializationFailed,
        'llama.cpp не смог загрузить эту GGUF-модель. Возможные причины: архитектура модели не поддерживается текущей версией llamadart/llama.cpp, файл скачан не полностью или модель слишком новая для встроенного backend. Попробуйте другую GGUF-модель, например Qwen2.5 Instruct GGUF с квантованием Q4_K_M. Техническая ошибка: $error',
      );
    }
  }

  @override
  Stream<String> generate({
    required String prompt,
    int maxTokens = 128,
    double temperature = 0.7,
    String? grammar,
    List<String> stopSequences = const [],
  }) async* {
    if (!_isInitialized) {
      throw const LlmServiceException(
        LlmServiceErrorCode.notInitialized,
        'LLM не инициализирована.',
      );
    }

    try {
      yield* _activeEngine.generate(
        prompt,
        params: GenerationParams(
          temp: temperature,
          topP: 0.9,
          topK: 40,
          maxTokens: maxTokens,
          penalty: 1.1,
          grammar: grammar,
          stopSequences: stopSequences,
        ),
      );
    } catch (error) {
      throw LlmServiceException(
        LlmServiceErrorCode.generationFailed,
        'Ошибка генерации: $error',
      );
    }
  }

  @override
  Future<void> dispose() async {
    final engine = _engine;
    if (engine == null) {
      _isInitialized = false;
      return;
    }

    try {
      await engine.dispose();
    } finally {
      _engine = null;
      _isInitialized = false;
    }
  }
}
