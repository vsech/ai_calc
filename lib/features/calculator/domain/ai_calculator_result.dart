enum AiResultSource {
  llm,
  mock,
  fallback,
}

class AiCalculatorResult {
  const AiCalculatorResult({
    required this.shortAnswer,
    required this.explanation,
    required this.confidence,
    required this.mood,
    required this.source,
  });

  final String shortAnswer;
  final String explanation;
  final double confidence;
  final String mood;
  final AiResultSource source;
}
