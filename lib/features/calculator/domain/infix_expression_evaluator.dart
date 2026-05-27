import '../../../shared/errors/expression_evaluation_exception.dart';
import 'expression_evaluator.dart';

class InfixExpressionEvaluator implements ExpressionEvaluator {
  const InfixExpressionEvaluator();

  @override
  double evaluate(String expression) {
    final parser = _ExpressionParser(expression);
    return parser.parse();
  }
}

class _ExpressionParser {
  _ExpressionParser(String raw) : _input = raw.replaceAll(' ', '');

  final String _input;
  int _index = 0;

  double parse() {
    if (_input.isEmpty) {
      throw const ExpressionEvaluationException(
        ExpressionErrorCode.emptyExpression,
        'Выражение не может быть пустым.',
      );
    }
    final result = _parseExpression();
    if (!_isAtEnd) {
      throw ExpressionEvaluationException(
        ExpressionErrorCode.invalidSyntax,
        'Неожиданный токен "${_peek()}" в позиции $_index.',
      );
    }
    return result;
  }

  double _parseExpression() {
    var value = _parseTerm();
    while (true) {
      if (_match('+')) {
        value += _parseTerm();
      } else if (_match('-')) {
        value -= _parseTerm();
      } else {
        break;
      }
    }
    return value;
  }

  double _parseTerm() {
    var value = _parseFactor();
    while (true) {
      if (_match('*')) {
        value *= _parseFactor();
      } else if (_match('/')) {
        final divisor = _parseFactor();
        if (divisor.abs() < 1e-12) {
          throw const ExpressionEvaluationException(
            ExpressionErrorCode.divisionByZero,
            'Деление на ноль невозможно.',
          );
        }
        value /= divisor;
      } else {
        break;
      }
    }
    return value;
  }

  double _parseFactor() {
    if (_match('+')) {
      return _parseFactor();
    }
    if (_match('-')) {
      return -_parseFactor();
    }
    if (_match('(')) {
      final value = _parseExpression();
      if (!_match(')')) {
        throw const ExpressionEvaluationException(
          ExpressionErrorCode.invalidSyntax,
          'Пропущена закрывающая скобка.',
        );
      }
      return value;
    }
    return _parseNumber();
  }

  double _parseNumber() {
    final start = _index;
    var dotFound = false;

    while (!_isAtEnd) {
      final char = _peek();
      if (_isDigit(char)) {
        _index++;
        continue;
      }
      if (char == '.') {
        if (dotFound) {
          throw const ExpressionEvaluationException(
            ExpressionErrorCode.invalidSyntax,
            'Некорректное число: две десятичные точки.',
          );
        }
        dotFound = true;
        _index++;
        continue;
      }
      break;
    }

    if (start == _index) {
      throw ExpressionEvaluationException(
        ExpressionErrorCode.invalidSyntax,
        'Ожидалось число в позиции $_index.',
      );
    }

    final lexeme = _input.substring(start, _index);
    if (lexeme == '.') {
      throw const ExpressionEvaluationException(
        ExpressionErrorCode.invalidSyntax,
        'Одиночная точка не является числом.',
      );
    }

    final parsed = double.tryParse(lexeme);
    if (parsed == null) {
      throw ExpressionEvaluationException(
        ExpressionErrorCode.invalidSyntax,
        'Не удалось распознать число "$lexeme".',
      );
    }
    return parsed;
  }

  bool _match(String expected) {
    if (_isAtEnd || _peek() != expected) {
      return false;
    }
    _index++;
    return true;
  }

  bool _isDigit(String char) => char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;

  String _peek() => _input[_index];

  bool get _isAtEnd => _index >= _input.length;
}
