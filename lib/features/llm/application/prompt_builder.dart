import '../../calculator/domain/ai_calculator_mode.dart';

class PromptBuilder {
  const PromptBuilder();

  String buildPrompt({
    required String expression,
    required String correctResult,
    required AiCalculatorMode mode,
  }) {
    return '''
SYSTEM:
Ты самоуверенный AI-калькулятор. Пиши коротко, смешно и по делу.
Верни только JSON без markdown.
Schema:
{
  "short_answer": string,
  "explanation": string,
  "confidence": number,
  "mood": string
}

USER:
Expression: $expression
Correct result: $correctResult
Mode: ${mode.wireName}
Сгенерируй забавное объяснение результата.
''';
  }
}
