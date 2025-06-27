import 'dart:io';
import 'dart:developer' as developer;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
  fatal,
}

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  static const String _logFileName = 'app_logs.txt';
  static const int _maxLogFileSize = 5 * 1024 * 1024; // 5MB
  static const int _maxLogEntries = 1000;

  File? _logFile;
  List<String> _logBuffer = [];
  bool _isInitialized = false;

  /// Log service'i başlat
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final directory = await _getLogDirectory();
      _logFile = File('${directory.path}/$_logFileName');

      // Log dosyası yoksa oluştur
      if (!await _logFile!.exists()) {
        await _logFile!.create();
        await _logFile!.writeAsString('=== Uygulama Logları Başlatıldı ===\n');
      }

      _isInitialized = true;
      log(LogLevel.info, 'LogService başlatıldı');
    } catch (e) {
      developer.log('LogService başlatılamadı: $e', name: 'LogService');
    }
  }

  /// Log dizinini al
  Future<Directory> _getLogDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final appDocDir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${appDocDir.path}/logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      return logDir;
    } else {
      // Desktop için geçici dizin
      final tempDir = await getTemporaryDirectory();
      final logDir = Directory('${tempDir.path}/logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      return logDir;
    }
  }

  /// Log yaz
  void log(LogLevel level, String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    if (!_isInitialized) {
      developer.log('LogService henüz başlatılmadı', name: 'LogService');
      return;
    }

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = _getLevelString(level);
    final tagStr = tag != null ? '[$tag]' : '';
    final logEntry = '$timestamp $levelStr$tagStr: $message';

    // Console'a yaz (debug modda)
    if (kDebugMode) {
      developer.log(logEntry, name: 'AppLog');
      if (error != null) {
        developer.log('Error: $error', name: 'AppLog');
      }
      if (stackTrace != null) {
        developer.log('StackTrace: $stackTrace', name: 'AppLog');
      }
    }

    // Buffer'a ekle
    _logBuffer.add(logEntry);
    if (error != null) {
      _logBuffer.add('Error: $error');
    }
    if (stackTrace != null) {
      _logBuffer.add('StackTrace: $stackTrace');
    }

    // Buffer'ı dosyaya yaz
    _flushBuffer();

    // Log dosyası boyutunu kontrol et
    _checkLogFileSize();
  }

  /// Kısa log metodları
  void debug(String message, {String? tag}) =>
      log(LogLevel.debug, message, tag: tag);
  void info(String message, {String? tag}) =>
      log(LogLevel.info, message, tag: tag);
  void warning(String message, {String? tag}) =>
      log(LogLevel.warning, message, tag: tag);
  void error(String message,
          {String? tag, Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.error, message,
          tag: tag, error: error, stackTrace: stackTrace);
  void fatal(String message,
          {String? tag, Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.fatal, message,
          tag: tag, error: error, stackTrace: stackTrace);

  /// Log seviyesi string'ini al
  String _getLevelString(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '[DEBUG]';
      case LogLevel.info:
        return '[INFO]';
      case LogLevel.warning:
        return '[WARN]';
      case LogLevel.error:
        return '[ERROR]';
      case LogLevel.fatal:
        return '[FATAL]';
    }
  }

  /// Buffer'ı dosyaya yaz
  Future<void> _flushBuffer() async {
    if (_logBuffer.isEmpty || _logFile == null) return;

    try {
      final logText = _logBuffer.join('\n') + '\n';
      await _logFile!.writeAsString(logText, mode: FileMode.append);
      _logBuffer.clear();
    } catch (e) {
      developer.log('Log dosyasına yazılamadı: $e', name: 'LogService');
    }
  }

  /// Log dosyası boyutunu kontrol et
  Future<void> _checkLogFileSize() async {
    if (_logFile == null) return;

    try {
      final fileSize = await _logFile!.length();
      if (fileSize > _maxLogFileSize) {
        await _rotateLogFile();
      }
    } catch (e) {
      developer.log('Log dosyası boyutu kontrol edilemedi: $e',
          name: 'LogService');
    }
  }

  /// Log dosyasını döndür (eski logları yedekle)
  Future<void> _rotateLogFile() async {
    if (_logFile == null) return;

    try {
      final directory = await _getLogDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupFile =
          File('${directory.path}/app_logs_backup_$timestamp.txt');

      // Mevcut dosyayı yedekle
      await _logFile!.copy(backupFile.path);

      // Yeni dosya oluştur
      await _logFile!.writeAsString(
          '=== Log Dosyası Döndürüldü: ${DateTime.now().toIso8601String()} ===\n');

      // Eski yedek dosyaları temizle (5'ten fazla varsa)
      await _cleanOldBackupFiles(directory);

      info('Log dosyası döndürüldü: ${backupFile.path}');
    } catch (e) {
      developer.log('Log dosyası döndürülemedi: $e', name: 'LogService');
    }
  }

  /// Eski yedek dosyaları temizle
  Future<void> _cleanOldBackupFiles(Directory directory) async {
    try {
      final files = directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.contains('app_logs_backup_'))
          .toList();

      if (files.length > 5) {
        // En eski dosyaları sil
        files.sort(
            (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
        for (int i = 0; i < files.length - 5; i++) {
          await files[i].delete();
        }
      }
    } catch (e) {
      developer.log('Eski yedek dosyalar temizlenemedi: $e',
          name: 'LogService');
    }
  }

  /// Log dosyasını oku
  Future<String> getLogs() async {
    if (_logFile == null) return 'Log dosyası bulunamadı';

    try {
      // Buffer'ı önce dosyaya yaz
      await _flushBuffer();

      if (await _logFile!.exists()) {
        return await _logFile!.readAsString();
      } else {
        return 'Log dosyası mevcut değil';
      }
    } catch (e) {
      return 'Log dosyası okunamadı: $e';
    }
  }

  /// Log dosyasını paylaş
  Future<void> shareLogs() async {
    try {
      final logs = await getLogs();
      final directory = await _getLogDirectory();
      final shareFile = File('${directory.path}/shared_logs.txt');

      // Paylaşım için dosya oluştur
      await shareFile.writeAsString(logs);

      // Dosyayı paylaş
      await Share.shareXFiles(
        [XFile(shareFile.path)],
        text: 'Backgammon Score Tracker - Uygulama Logları',
      );
    } catch (e) {
      developer.log('Loglar paylaşılamadı: $e', name: 'LogService');
    }
  }

  /// Log dosyasını temizle
  Future<void> clearLogs() async {
    if (_logFile == null) return;

    try {
      await _logFile!.writeAsString(
          '=== Loglar Temizlendi: ${DateTime.now().toIso8601String()} ===\n');
      _logBuffer.clear();
      info('Loglar temizlendi');
    } catch (e) {
      developer.log('Loglar temizlenemedi: $e', name: 'LogService');
    }
  }

  /// Log dosyası boyutunu al
  Future<String> getLogFileSize() async {
    if (_logFile == null) return '0 KB';

    try {
      if (await _logFile!.exists()) {
        final size = await _logFile!.length();
        if (size < 1024) {
          return '${size} B';
        } else if (size < 1024 * 1024) {
          return '${(size / 1024).toStringAsFixed(1)} KB';
        } else {
          return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
        }
      } else {
        return '0 KB';
      }
    } catch (e) {
      return 'Bilinmiyor';
    }
  }

  /// Uygulama kapanırken buffer'ı temizle
  Future<void> dispose() async {
    await _flushBuffer();
    _isInitialized = false;
  }
}
