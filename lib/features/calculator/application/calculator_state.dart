import '../../llm/infrastructure/model_manager.dart';
import '../domain/ai_calculator_mode.dart';
import '../domain/calculator_interface_mode.dart';

enum CalculatorStatus { idle, modelLoading, ready, generating, error }

class CalculatorState {
  const CalculatorState({
    required this.expression,
    required this.result,
    required this.aiText,
    required this.status,
    required this.mode,
    required this.interfaceMode,
    required this.errorMessage,
    required this.model,
    required this.confidence,
    required this.mood,
    required this.modelDownloadProgress,
    required this.isModelDownloading,
    required this.isLlmInitialized,
  });

  factory CalculatorState.initial() {
    return const CalculatorState(
      expression: '',
      result: null,
      aiText: '',
      status: CalculatorStatus.idle,
      mode: AiCalculatorMode.normal,
      interfaceMode: CalculatorInterfaceMode.lite,
      errorMessage: null,
      model: null,
      confidence: null,
      mood: null,
      modelDownloadProgress: null,
      isModelDownloading: false,
      isLlmInitialized: false,
    );
  }

  final String expression;
  final String? result;
  final String aiText;
  final CalculatorStatus status;
  final AiCalculatorMode mode;
  final CalculatorInterfaceMode interfaceMode;
  final String? errorMessage;
  final ModelDescriptor? model;
  final double? confidence;
  final String? mood;
  final double? modelDownloadProgress;
  final bool isModelDownloading;
  final bool isLlmInitialized;

  bool get modelConfigured => model != null;

  CalculatorState copyWith({
    String? expression,
    String? result,
    bool clearResult = false,
    String? aiText,
    CalculatorStatus? status,
    AiCalculatorMode? mode,
    CalculatorInterfaceMode? interfaceMode,
    String? errorMessage,
    bool clearError = false,
    ModelDescriptor? model,
    bool clearModel = false,
    double? confidence,
    bool clearConfidence = false,
    String? mood,
    bool clearMood = false,
    double? modelDownloadProgress,
    bool clearModelDownloadProgress = false,
    bool? isModelDownloading,
    bool? isLlmInitialized,
  }) {
    return CalculatorState(
      expression: expression ?? this.expression,
      result: clearResult ? null : (result ?? this.result),
      aiText: aiText ?? this.aiText,
      status: status ?? this.status,
      mode: mode ?? this.mode,
      interfaceMode: interfaceMode ?? this.interfaceMode,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      model: clearModel ? null : (model ?? this.model),
      confidence: clearConfidence ? null : (confidence ?? this.confidence),
      mood: clearMood ? null : (mood ?? this.mood),
      modelDownloadProgress: clearModelDownloadProgress
          ? null
          : (modelDownloadProgress ?? this.modelDownloadProgress),
      isModelDownloading: isModelDownloading ?? this.isModelDownloading,
      isLlmInitialized: isLlmInitialized ?? this.isLlmInitialized,
    );
  }
}
