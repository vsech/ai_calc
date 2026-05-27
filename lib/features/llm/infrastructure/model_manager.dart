import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModelDescriptor {
  const ModelDescriptor({
    required this.modelRef,
    required this.fileName,
    required this.sizeBytes,
  });

  final String modelRef;
  final String fileName;
  final int sizeBytes;

  bool get isUri => modelRef.toLowerCase().startsWith('content://');
}

class ModelValidationResult {
  const ModelValidationResult({required this.isValid, this.message});

  final bool isValid;
  final String? message;
}

class ModelManager {
  static const _modelRefKey = 'selected_model_ref';
  static const _modelNameKey = 'selected_model_name';
  static const _modelSizeKey = 'selected_model_size';

  Future<ModelDescriptor?> loadSavedModel() async {
    final prefs = await SharedPreferences.getInstance();
    final modelRef = prefs.getString(_modelRefKey);
    if (modelRef == null || modelRef.isEmpty) {
      return null;
    }
    return ModelDescriptor(
      modelRef: modelRef,
      fileName: prefs.getString(_modelNameKey) ?? 'model.gguf',
      sizeBytes: prefs.getInt(_modelSizeKey) ?? 0,
    );
  }

  Future<ModelDescriptor?> chooseModel() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gguf'],
      allowMultiple: false,
      withData: false,
      withReadStream: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    final filePath = file.path;
    final identifier = file.identifier;
    if ((filePath == null || filePath.isEmpty) && file.readStream == null) {
      return null;
    }

    if (identifier != null &&
        identifier.toLowerCase().startsWith('content://')) {
      final descriptor = await _copyPickedModelToAppStorage(file);
      await _persistModel(descriptor);
      return descriptor;
    }

    final descriptor = ModelDescriptor(
      modelRef: filePath!,
      fileName: file.name,
      sizeBytes: file.size,
    );
    await _persistModel(descriptor);
    return descriptor;
  }

  Future<ModelDescriptor> downloadModel({
    required String url,
    required void Function(double progress) onProgress,
  }) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https'))) {
      throw const ModelDownloadException('Некорректная ссылка на модель.');
    }

    final modelsDir = await _localModelsDirectory();

    var fileName = _sanitizeFileName(_extractFileName(uri));
    if (!fileName.toLowerCase().endsWith('.gguf')) {
      fileName = '$fileName.gguf';
    }

    final existing = await _existingValidModelFile(modelsDir, fileName);
    if (existing != null) {
      final descriptor = ModelDescriptor(
        modelRef: existing.path,
        fileName: existing.uri.pathSegments.last,
        sizeBytes: await existing.length(),
      );
      await _persistModel(descriptor);
      onProgress(1);
      return descriptor;
    }

    final client = http.Client();
    late final http.StreamedResponse response;
    try {
      final request = http.Request('GET', uri)
        ..headers.addAll(const {
          'Accept': 'application/octet-stream',
          'User-Agent': 'ai-calc/1.0',
        })
        ..followRedirects = true
        ..maxRedirects = 10;
      response = await client.send(request);
    } on SocketException catch (error) {
      client.close();
      throw ModelDownloadException(
        'Не удалось подключиться к серверу модели. Проверьте интернет на устройстве, DNS и что приложение установлено со свежим AndroidManifest с разрешением INTERNET. Техническая ошибка: ${error.message}',
      );
    } catch (error) {
      client.close();
      throw ModelDownloadException('Не удалось начать загрузку модели: $error');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      client.close();
      throw ModelDownloadException(
        'Не удалось скачать модель: HTTP ${response.statusCode}.',
      );
    }

    final target = await _availableModelFile(modelsDir, fileName);

    final sink = target.openWrite();
    final total = response.contentLength ?? 0;
    var downloaded = 0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (total > 0) {
          onProgress(downloaded / total);
        }
      }
      await sink.flush();
      await sink.close();
      onProgress(1);
    } catch (error) {
      await sink.close();
      if (await target.exists()) {
        await target.delete();
      }
      throw ModelDownloadException('Ошибка записи модели в файл: $error');
    } finally {
      client.close();
    }

    final size = await target.length();
    if (size <= 0) {
      throw const ModelDownloadException('Скачанный файл пустой.');
    }
    if (!await _hasGgufMagic(target)) {
      await target.delete();
      throw const ModelDownloadException(
        'Скачанный файл не является GGUF-моделью. Проверьте, что ссылка ведет напрямую на .gguf файл.',
      );
    }

    final descriptor = ModelDescriptor(
      modelRef: target.path,
      fileName: fileName,
      sizeBytes: size,
    );
    await _persistModel(descriptor);
    return descriptor;
  }

  Future<File?> _existingValidModelFile(
    Directory modelsDir,
    String fileName,
  ) async {
    final candidate = File(
      '${modelsDir.path}${Platform.pathSeparator}${_sanitizeFileName(fileName)}',
    );
    if (!await candidate.exists()) {
      return null;
    }
    if (await candidate.length() <= 0 || !await _hasGgufMagic(candidate)) {
      return null;
    }
    return candidate;
  }

  Future<void> resetModel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_modelRefKey);
    await prefs.remove(_modelNameKey);
    await prefs.remove(_modelSizeKey);
  }

  Future<ModelValidationResult> validateModel(ModelDescriptor model) async {
    if (model.sizeBytes <= 0) {
      return const ModelValidationResult(
        isValid: false,
        message: 'Файл модели пустой или недоступен.',
      );
    }

    if (model.isUri) {
      return const ModelValidationResult(
        isValid: false,
        message:
            'content:// URI не поддерживается llama.cpp напрямую. Выберите модель повторно, чтобы приложение скопировало ее в локальное хранилище.',
      );
    }

    final file = File(model.modelRef);
    if (!await file.exists()) {
      return const ModelValidationResult(
        isValid: false,
        message: 'Файл модели не найден. Выберите модель повторно.',
      );
    }

    final length = await file.length();
    if (length <= 0) {
      return const ModelValidationResult(
        isValid: false,
        message: 'Файл модели поврежден или пуст.',
      );
    }
    if (!await _hasGgufMagic(file)) {
      return const ModelValidationResult(
        isValid: false,
        message:
            'Файл не является GGUF-моделью или был скачан не полностью. Выберите или скачайте корректный .gguf файл.',
      );
    }

    return const ModelValidationResult(isValid: true);
  }

  Future<void> _persistModel(ModelDescriptor model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelRefKey, model.modelRef);
    await prefs.setString(_modelNameKey, model.fileName);
    await prefs.setInt(_modelSizeKey, model.sizeBytes);
  }

  Future<Directory> _localModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(
      '${appDir.path}${Platform.pathSeparator}models',
    );
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  Future<ModelDescriptor> _copyPickedModelToAppStorage(
    PlatformFile file,
  ) async {
    var fileName = _sanitizeFileName(file.name);
    if (!fileName.toLowerCase().endsWith('.gguf')) {
      fileName = '$fileName.gguf';
    }

    final modelsDir = await _localModelsDirectory();
    final target = await _availableModelFile(modelsDir, fileName);
    final sourcePath = file.path;

    if (sourcePath != null && sourcePath.isNotEmpty) {
      final source = File(sourcePath);
      if (await source.exists()) {
        await source.copy(target.path);
      } else if (file.readStream != null) {
        await _writeStreamToFile(file.readStream!, target);
      } else {
        throw const ModelDownloadException(
          'Не удалось прочитать выбранный файл модели.',
        );
      }
    } else if (file.readStream != null) {
      await _writeStreamToFile(file.readStream!, target);
    } else {
      throw const ModelDownloadException(
        'Не удалось прочитать выбранный файл модели.',
      );
    }

    final size = await target.length();
    if (size <= 0) {
      if (await target.exists()) {
        await target.delete();
      }
      throw const ModelDownloadException('Выбранный файл модели пустой.');
    }
    if (!await _hasGgufMagic(target)) {
      if (await target.exists()) {
        await target.delete();
      }
      throw const ModelDownloadException(
        'Выбранный файл не является GGUF-моделью или был поврежден при копировании.',
      );
    }

    return ModelDescriptor(
      modelRef: target.path,
      fileName: target.uri.pathSegments.last,
      sizeBytes: size,
    );
  }

  Future<void> _writeStreamToFile(Stream<List<int>> stream, File target) async {
    final sink = target.openWrite();
    try {
      await for (final chunk in stream) {
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
    } catch (_) {
      await sink.close();
      if (await target.exists()) {
        await target.delete();
      }
      rethrow;
    }
  }

  Future<bool> _hasGgufMagic(File file) async {
    if (!await file.exists() || await file.length() < 4) {
      return false;
    }

    final reader = await file.open();
    try {
      final bytes = await reader.read(4);
      return bytes.length == 4 &&
          bytes[0] == 0x47 &&
          bytes[1] == 0x47 &&
          bytes[2] == 0x55 &&
          bytes[3] == 0x46;
    } finally {
      await reader.close();
    }
  }

  Future<File> _availableModelFile(Directory modelsDir, String fileName) async {
    final normalized = _sanitizeFileName(fileName);
    final dotIndex = normalized.lastIndexOf('.');
    final baseName = dotIndex <= 0
        ? normalized
        : normalized.substring(0, dotIndex);
    final extension = dotIndex <= 0 ? '' : normalized.substring(dotIndex);

    var candidate = File(
      '${modelsDir.path}${Platform.pathSeparator}$normalized',
    );
    var suffix = 1;
    while (await candidate.exists()) {
      candidate = File(
        '${modelsDir.path}${Platform.pathSeparator}${baseName}_$suffix$extension',
      );
      suffix += 1;
    }
    return candidate;
  }

  String _extractFileName(Uri uri) {
    final segment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    if (segment.isEmpty) {
      return 'model_${DateTime.now().millisecondsSinceEpoch}.gguf';
    }
    return Uri.decodeComponent(segment);
  }

  String _sanitizeFileName(String fileName) {
    final sanitized = fileName.trim().replaceAll(
      RegExp(r'[<>:"/\\|?*\x00-\x1F]'),
      '_',
    );
    if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') {
      return 'model_${DateTime.now().millisecondsSinceEpoch}.gguf';
    }
    return sanitized;
  }
}

class ModelDownloadException implements Exception {
  const ModelDownloadException(this.message);

  final String message;

  @override
  String toString() => 'ModelDownloadException: $message';
}
