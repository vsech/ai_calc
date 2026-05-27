import 'package:ai_calc/app.dart';
import 'package:ai_calc/features/calculator/application/providers.dart';
import 'package:ai_calc/features/llm/application/llm_service.dart';
import 'package:ai_calc/features/llm/infrastructure/model_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  testWidgets('calculator screen renders lite controls by default', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
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

    expect(find.text('AI Calculator'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.text('Normal'), findsNothing);
    expect(find.text('Chaotic AI'), findsNothing);
    expect(find.text('Corporate AI'), findsNothing);
    expect(find.text('Philosopher'), findsNothing);
    expect(find.text('='), findsOneWidget);
    expect(find.text('Нужна маленькая модель'), findsOneWidget);
    expect(find.text('Скачать модель'), findsOneWidget);
  });

  testWidgets('settings can reveal advanced interface', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
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

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();

    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Chaotic AI'), findsOneWidget);
    expect(find.text('Corporate AI'), findsOneWidget);
    expect(find.text('Philosopher'), findsOneWidget);
    expect(find.textContaining('GGUF модель:'), findsOneWidget);
  });
}
