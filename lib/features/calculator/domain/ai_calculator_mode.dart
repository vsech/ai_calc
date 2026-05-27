enum AiCalculatorMode {
  normal,
  chaoticAi,
  corporateAi,
  philosopher;

  String get wireName => switch (this) {
        AiCalculatorMode.normal => 'normal',
        AiCalculatorMode.chaoticAi => 'chaotic_ai',
        AiCalculatorMode.corporateAi => 'corporate_ai',
        AiCalculatorMode.philosopher => 'philosopher',
      };

  String get label => switch (this) {
        AiCalculatorMode.normal => 'Normal',
        AiCalculatorMode.chaoticAi => 'Chaotic AI',
        AiCalculatorMode.corporateAi => 'Corporate AI',
        AiCalculatorMode.philosopher => 'Philosopher',
      };
}
