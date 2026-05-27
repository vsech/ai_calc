abstract interface class LlmService {
  Future<void> initialize({required String modelPath});

  Stream<String> generate({
    required String prompt,
    int maxTokens = 128,
    double temperature = 0.7,
    String? grammar,
    List<String> stopSequences = const [],
  });

  Future<void> dispose();
}
