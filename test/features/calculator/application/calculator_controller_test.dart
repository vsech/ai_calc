import 'package:ai_calc/features/calculator/application/calculator_controller.dart';
import 'package:ai_calc/features/calculator/application/calculator_state.dart';
import 'package:ai_calc/features/calculator/application/providers.dart';
import 'package:ai_calc/features/calculator/domain/ai_calculator_mode.dart';
import 'package:ai_calc/features/calculator/domain/calculator_interface_mode.dart';
import 'package:ai_calc/features/llm/application/llm_service.dart';
import 'package:ai_calc/features/llm/infrastructure/model_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoModelManager extends ModelManager {
  var downloadCount = 0;

  @override
  Future<ModelDescriptor?> loadSavedModel() async => null;

  @override
  Future<ModelDescriptor> downloadModel({
    required String url,
    required void Function(double progress) onProgress,
  }) async {
    downloadCount += 1;
    throw StateError('unexpected download');
  }
}

class _SavedModelManager extends ModelManager {
  @override
  Future<ModelDescriptor?> loadSavedModel() async {
    return const ModelDescriptor(
      modelRef: 'content://downloads/model.gguf',
      fileName: 'model.gguf',
      sizeBytes: 1024,
    );
  }

  @override
  Future<ModelValidationResult> validateModel(ModelDescriptor model) async {
    return const ModelValidationResult(isValid: true);
  }
}

class _DownloadModelManager extends _NoModelManager {
  String? lastUrl;

  @override
  Future<ModelDescriptor> downloadModel({
    required String url,
    required void Function(double progress) onProgress,
  }) async {
    downloadCount += 1;
    lastUrl = url;
    onProgress(0.5);
    onProgress(1);
    return const ModelDescriptor(
      modelRef: 'content://downloads/model.gguf',
      fileName: 'model.gguf',
      sizeBytes: 1024,
    );
  }

  @override
  Future<ModelValidationResult> validateModel(ModelDescriptor model) async {
    return const ModelValidationResult(isValid: true);
  }
}

class _FakeLlmService implements LlmService {
  _FakeLlmService(this._response);

  final String _response;
  bool _initialized = false;
  double? lastTemperature;
  String? lastGrammar;
  List<String>? lastStopSequences;

  @override
  Future<void> initialize({required String modelPath}) async {
    _initialized = true;
  }

  @override
  Stream<String> generate({
    required String prompt,
    int maxTokens = 128,
    double temperature = 0.7,
    String? grammar,
    List<String> stopSequences = const [],
  }) async* {
    if (!_initialized) {
      throw StateError('not initialized');
    }
    lastTemperature = temperature;
    lastGrammar = grammar;
    lastStopSequences = stopSequences;
    for (final rune in _response.runes) {
      yield String.fromCharCode(rune);
    }
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
  }
}

void main() {
  Future<ProviderContainer> createContainer({
    required LlmService llmService,
    required ModelManager modelManager,
    Map<String, Object> preferences = const {},
  }) async {
    SharedPreferences.setMockInitialValues(preferences);
    final container = ProviderContainer(
      overrides: [
        modelManagerProvider.overrideWith((_) => modelManager),
        llmServiceProvider.overrideWith((_) => llmService),
      ],
    );
    container.read(calculatorControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  test('defaults to lite interface mode without saved preference', () async {
    final container = await createContainer(
      llmService: _FakeLlmService(
        '{"short_answer":"6","explanation":"ok","confidence":0.9,"mood":"normal"}',
      ),
      modelManager: _NoModelManager(),
    );
    addTearDown(container.dispose);

    final state = container.read(calculatorControllerProvider);

    expect(state.interfaceMode, CalculatorInterfaceMode.lite);
  });

  test('persists advanced interface mode preference', () async {
    final container = await createContainer(
      llmService: _FakeLlmService(
        '{"short_answer":"6","explanation":"ok","confidence":0.9,"mood":"normal"}',
      ),
      modelManager: _NoModelManager(),
    );
    addTearDown(container.dispose);

    final controller = container.read(calculatorControllerProvider.notifier);
    await controller.setInterfaceMode(CalculatorInterfaceMode.advanced);
    final prefs = await SharedPreferences.getInstance();

    expect(
      container.read(calculatorControllerProvider).interfaceMode,
      CalculatorInterfaceMode.advanced,
    );
    expect(prefs.getString('calculator_interface_mode'), 'advanced');
  });

  test('shows explicit error when model is not loaded', () async {
    final container = await createContainer(
      llmService: _FakeLlmService(
        '{"short_answer":"6","explanation":"ok","confidence":0.9,"mood":"normal"}',
      ),
      modelManager: _NoModelManager(),
    );
    addTearDown(container.dispose);

    final controller = container.read(calculatorControllerProvider.notifier);
    controller.appendToken('2');
    controller.appendToken('+');
    controller.appendToken('2');

    await controller.evaluateAndExplain();
    final state = container.read(calculatorControllerProvider);

    expect(state.status, CalculatorStatus.error);
    expect(state.errorMessage, contains('Модель не загружена'));
  });

  test(
    'evaluates expression and applies llm response with loaded model',
    () async {
      final llmService = _FakeLlmService(
        '{"short_answer":"6","explanation":"ok","confidence":0.9,"mood":"normal"}',
      );
      final container = await createContainer(
        llmService: llmService,
        modelManager: _SavedModelManager(),
      );
      addTearDown(container.dispose);

      final controller = container.read(calculatorControllerProvider.notifier);
      await controller.setInterfaceMode(CalculatorInterfaceMode.advanced);
      controller.appendToken('2');
      controller.appendToken('+');
      controller.appendToken('2');
      controller.appendToken('*');
      controller.appendToken('2');

      await controller.evaluateAndExplain();
      final state = container.read(calculatorControllerProvider);

      expect(state.status, CalculatorStatus.ready);
      expect(state.result, '6');
      expect(state.aiText, 'ok');
      expect(llmService.lastTemperature, 0);
      expect(llmService.lastGrammar, contains('short_answer'));
      expect(llmService.lastStopSequences, contains('```'));
    },
  );

  test('chaotic mode distorts numeric result', () async {
    final container = await createContainer(
      llmService: _FakeLlmService(
        '{"short_answer":"6","explanation":"chaos","confidence":0.7,"mood":"chaotic_ai"}',
      ),
      modelManager: _SavedModelManager(),
    );
    addTearDown(container.dispose);

    final controller = container.read(calculatorControllerProvider.notifier);
    await controller.setInterfaceMode(CalculatorInterfaceMode.advanced);
    controller.setMode(AiCalculatorMode.chaoticAi);
    controller.appendToken('2');
    controller.appendToken('+');
    controller.appendToken('2');
    controller.appendToken('*');
    controller.appendToken('2');

    await controller.evaluateAndExplain();
    final state = container.read(calculatorControllerProvider);

    expect(state.result, isNot('6'));
  });

  test('returns explicit error when llm output is invalid json', () async {
    final container = await createContainer(
      llmService: _FakeLlmService('not-json'),
      modelManager: _SavedModelManager(),
    );
    addTearDown(container.dispose);

    final controller = container.read(calculatorControllerProvider.notifier);
    controller.appendToken('1');
    controller.appendToken('+');
    controller.appendToken('1');

    await controller.evaluateAndExplain();
    final state = container.read(calculatorControllerProvider);

    expect(state.status, CalculatorStatus.error);
    expect(state.errorMessage, contains('невалидный JSON'));
  });

  test('accepts json wrapped in markdown and surrounding text', () async {
    final container = await createContainer(
      llmService: _FakeLlmService(
        'text before\n```json\n'
        '{"short_answer":"2","explanation":"wrapped","confidence":0.8,"mood":"normal"}'
        '\n```\ntext after',
      ),
      modelManager: _SavedModelManager(),
    );
    addTearDown(container.dispose);

    final controller = container.read(calculatorControllerProvider.notifier);
    controller.appendToken('1');
    controller.appendToken('+');
    controller.appendToken('1');

    await controller.evaluateAndExplain();
    final state = container.read(calculatorControllerProvider);

    expect(state.status, CalculatorStatus.ready);
    expect(state.aiText, 'wrapped');
    expect(state.confidence, 0.8);
  });

  test('downloads model from URL and marks it selected', () async {
    final container = await createContainer(
      llmService: _FakeLlmService(
        '{"short_answer":"2","explanation":"ok","confidence":0.9,"mood":"normal"}',
      ),
      modelManager: _DownloadModelManager(),
    );
    addTearDown(container.dispose);

    final controller = container.read(calculatorControllerProvider.notifier);
    await controller.downloadModelFromUrl('https://example.com/model.gguf');
    final state = container.read(calculatorControllerProvider);

    expect(state.status, CalculatorStatus.ready);
    expect(state.isModelDownloading, isFalse);
    expect(state.modelDownloadProgress, 1);
    expect(state.model?.fileName, 'model.gguf');
    expect(state.isLlmInitialized, isTrue);
  });

  test('does not download missing model during lite bootstrap', () async {
    final modelManager = _NoModelManager();
    final container = await createContainer(
      llmService: _FakeLlmService(
        '{"short_answer":"2","explanation":"ok","confidence":0.9,"mood":"normal"}',
      ),
      modelManager: modelManager,
    );
    addTearDown(container.dispose);

    expect(
      container.read(calculatorControllerProvider).interfaceMode,
      CalculatorInterfaceMode.lite,
    );
    expect(modelManager.downloadCount, 0);
  });

  test('downloads lite default model from smallest recommended URL', () async {
    final modelManager = _DownloadModelManager();
    final container = await createContainer(
      llmService: _FakeLlmService(
        '{"short_answer":"2","explanation":"ok","confidence":0.9,"mood":"normal"}',
      ),
      modelManager: modelManager,
    );
    addTearDown(container.dispose);

    final controller = container.read(calculatorControllerProvider.notifier);
    await controller.downloadLiteDefaultModel();

    expect(modelManager.downloadCount, 1);
    expect(modelManager.lastUrl, CalculatorController.liteDefaultModelUrl);
  });

  test('lite visible result uses generated explanation', () async {
    final container = await createContainer(
      llmService: _FakeLlmService(
        '{"short_answer":"model answer","explanation":"hidden work","confidence":0.9,"mood":"normal"}',
      ),
      modelManager: _SavedModelManager(),
    );
    addTearDown(container.dispose);

    final controller = container.read(calculatorControllerProvider.notifier);
    controller.appendToken('1');
    controller.appendToken('+');
    controller.appendToken('1');

    await controller.evaluateAndExplain();
    final state = container.read(calculatorControllerProvider);

    expect(state.interfaceMode, CalculatorInterfaceMode.lite);
    expect(state.result, 'hidden work');
    expect(state.aiText, 'hidden work');
  });
}
