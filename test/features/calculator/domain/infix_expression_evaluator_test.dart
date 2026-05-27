import 'package:ai_calc/features/calculator/domain/infix_expression_evaluator.dart';
import 'package:ai_calc/shared/errors/expression_evaluation_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const evaluator = InfixExpressionEvaluator();

  test('evaluates operator precedence and parentheses', () {
    expect(evaluator.evaluate('2 + 2 * 2'), 6);
    expect(evaluator.evaluate('(2 + 2) * 2'), 8);
    expect(evaluator.evaluate('3.5 + 1.5'), 5);
    expect(evaluator.evaluate('-5 + 2'), -3);
  });

  test('throws division by zero', () {
    expect(
      () => evaluator.evaluate('4 / (2 - 2)'),
      throwsA(
        isA<ExpressionEvaluationException>()
            .having((e) => e.code, 'code', ExpressionErrorCode.divisionByZero),
      ),
    );
  });

  test('throws invalid syntax', () {
    expect(
      () => evaluator.evaluate('2++'),
      throwsA(
        isA<ExpressionEvaluationException>()
            .having((e) => e.code, 'code', ExpressionErrorCode.invalidSyntax),
      ),
    );
  });
}
