import 'dart:io';

import 'package:ai_calc/features/llm/infrastructure/model_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('content uri model is not valid for direct llama.cpp loading', () async {
    final manager = ModelManager();

    final validation = await manager.validateModel(
      const ModelDescriptor(
        modelRef: 'content://downloads/model.gguf',
        fileName: 'model.gguf',
        sizeBytes: 1024,
      ),
    );

    expect(validation.isValid, isFalse);
    expect(validation.message, contains('content:// URI'));
  });

  test('content uri detection is case insensitive', () {
    const model = ModelDescriptor(
      modelRef: 'CONTENT://downloads/model.gguf',
      fileName: 'model.gguf',
      sizeBytes: 1024,
    );

    expect(model.isUri, isTrue);
  });

  test('rejects file without gguf magic header', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'ai_calc_model_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final file = File('${tempDir.path}${Platform.pathSeparator}model.gguf');
    await file.writeAsString('<html>not a model</html>');

    final manager = ModelManager();
    final validation = await manager.validateModel(
      ModelDescriptor(
        modelRef: file.path,
        fileName: 'model.gguf',
        sizeBytes: await file.length(),
      ),
    );

    expect(validation.isValid, isFalse);
    expect(validation.message, contains('GGUF'));
  });

  test('accepts file with gguf magic header', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'ai_calc_model_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final file = File('${tempDir.path}${Platform.pathSeparator}model.gguf');
    await file.writeAsBytes([0x47, 0x47, 0x55, 0x46, 0, 0, 0, 0]);

    final manager = ModelManager();
    final validation = await manager.validateModel(
      ModelDescriptor(
        modelRef: file.path,
        fileName: 'model.gguf',
        sizeBytes: await file.length(),
      ),
    );

    expect(validation.isValid, isTrue);
  });
}
