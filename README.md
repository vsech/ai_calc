# AI Calculator / НейроКалькулятор

Flutter-калькулятор для Android, где математика считается локальным парсером, а LLM объясняет результат с разным стилем.

## Что уже реализовано (MVP stage 1-5)

- Новый экран калькулятора с keypad, результатом, AI-панелью и выбором режима.
- Режимы: `normal`, `chaotic_ai`, `corporate_ai`, `philosopher`.
- Арифметический движок с приоритетами, скобками и validation-ошибками.
- `LlmService` abstraction + stream-based `MockLlmService`.
- `PromptBuilder` (RU prompts, JSON schema).
- `ModelManager` для выбора GGUF, сохранения ссылки и reset.
- `ModelManager` для выбора GGUF, загрузки GGUF по URL, сохранения ссылки и reset.
- `LlamaCppLlmService` на `llamadart` для локальной генерации через GGUF-модель.

## Запуск

```bash
flutter pub get
flutter run -d android
```

## Тесты

```bash
flutter test
```
