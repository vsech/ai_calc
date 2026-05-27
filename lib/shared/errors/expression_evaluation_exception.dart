enum ExpressionErrorCode {
  emptyExpression,
  invalidSyntax,
  divisionByZero,
}

class ExpressionEvaluationException implements Exception {
  const ExpressionEvaluationException(this.code, this.message);

  final ExpressionErrorCode code;
  final String message;

  @override
  String toString() => 'ExpressionEvaluationException($code): $message';
}
