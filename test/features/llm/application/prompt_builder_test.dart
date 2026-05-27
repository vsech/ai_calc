import 'package:ai_calc/features/calculator/domain/ai_calculator_mode.dart';
import 'package:ai_calc/features/llm/application/prompt_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = PromptBuilder();

  test('builds russian prompt with mode and result', () {
    final prompt = builder.buildPrompt(
      expression: '2 + 2 * 2',
      correctResult: '6',
      mode: AiCalculatorMode.corporateAi,
    );

    expect(prompt, contains('Expression: 2 + 2 * 2'));
    expect(prompt, contains('Correct result: 6'));
    expect(prompt, contains('Mode: corporate_ai'));
    expect(prompt, contains('"short_answer"'));
    expect(prompt, contains('"explanation"'));
  });
}
