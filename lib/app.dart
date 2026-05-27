import 'package:flutter/material.dart';

import 'features/calculator/presentation/calculator_screen.dart';

class AiCalculatorApp extends StatelessWidget {
  const AiCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF455A64),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'AI Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF111417),
      ),
      home: const CalculatorScreen(),
    );
  }
}
