enum CalculatorInterfaceMode {
  lite,
  advanced;

  String get wireName => switch (this) {
    CalculatorInterfaceMode.lite => 'lite',
    CalculatorInterfaceMode.advanced => 'advanced',
  };

  String get label => switch (this) {
    CalculatorInterfaceMode.lite => 'Lite',
    CalculatorInterfaceMode.advanced => 'Advanced',
  };

  static CalculatorInterfaceMode fromWireName(String? value) {
    return switch (value) {
      'advanced' => CalculatorInterfaceMode.advanced,
      _ => CalculatorInterfaceMode.lite,
    };
  }
}
