import 'package:ai_calc/app.dart';
import 'package:ai_calc/features/calculator/application/providers.dart';
import 'package:ai_calc/features/llm/application/llm_service.dart';
import 'package:ai_calc/features/llm/infrastructure/model_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestModelManager extends ModelManager {
  @override
  Future<ModelDescriptor?> loadSavedModel() async => null;
}

class _TestLlmService implements LlmService {
  @override
  Future<void> initialize({required String modelPath}) async {}

  @override
  Stream<String> generate({
    required String prompt,
    int maxTokens = 128,
    double temperature = 0.7,
    String? grammar,
    List<String> stopSequences = const [],
  }) async* {}

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('calculator screen renders main controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modelManagerProvider.overrideWith((_) => _TestModelManager()),
          llmServiceProvider.overrideWith((_) => _TestLlmService()),
        ],
        child: const AiCalculatorApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI Calculator / НейроКалькулятор'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Chaotic AI'), findsOneWidget);
    expect(find.text('Corporate AI'), findsOneWidget);
    expect(find.text('Philosopher'), findsOneWidget);
    expect(find.text('='), findsOneWidget);
    expect(find.textContaining('Модель не загружена'), findsOneWidget);
  });
}
