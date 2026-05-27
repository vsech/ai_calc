import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../llm/application/llm_service.dart';
import '../../llm/application/prompt_builder.dart';
import '../../llm/infrastructure/llama_cpp_llm_service.dart';
import '../../llm/infrastructure/model_manager.dart';
import '../domain/expression_evaluator.dart';
import '../domain/infix_expression_evaluator.dart';

final expressionEvaluatorProvider = Provider<ExpressionEvaluator>(
  (_) => const InfixExpressionEvaluator(),
);

final promptBuilderProvider = Provider<PromptBuilder>(
  (_) => const PromptBuilder(),
);

final modelManagerProvider = Provider<ModelManager>(
  (_) => ModelManager(),
);

final llamaCppLlmServiceProvider = Provider<LlamaCppLlmService>(
  (_) => LlamaCppLlmService(),
);

final llmServiceProvider = Provider<LlmService>((ref) {
  return ref.watch(llamaCppLlmServiceProvider);
});
