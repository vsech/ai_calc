import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'calculator_controller.dart';
import 'calculator_state.dart';
export 'dependency_providers.dart';

final calculatorControllerProvider =
    NotifierProvider<CalculatorController, CalculatorState>(
  CalculatorController.new,
);
