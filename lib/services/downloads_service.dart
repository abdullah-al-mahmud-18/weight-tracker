import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

/// A user-facing failure while saving to Downloads.
class DownloadsException implements Exception {
  const DownloadsException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Saves files to the public Downloads folder via native Android code.
class DownloadsService {
  static const MethodChannel _channel = MethodChannel('weight_tracker/downloads');

  /// File name like `weight_tracker_20261003_081500.csv` (local time).
  static String exportFileName(DateTime now) =>
      'weight_tracker_${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';

  /// Saves [content] as [fileName] in Downloads and returns the saved name.
  ///
  /// Throws [DownloadsException] with a readable message on failure.
  Future<String> saveCsv(String fileName, String content) async {
    await _ensurePermission();
    try {
      final saved = await _channel.invokeMethod<String>('saveCsv', {
        'fileName': fileName,
        'content': content,
      });
      return saved ?? fileName;
    } on PlatformException catch (e) {
      throw DownloadsException(_messageFor(e));
    } on MissingPluginException {
      throw const DownloadsException('Saving files is not supported here.');
    }
  }

  /// Android 9 and below need WRITE_EXTERNAL_STORAGE; newer versions don't.
  Future<void> _ensurePermission() async {
    final sdkInt = await _channel.invokeMethod<int>('sdkInt') ?? 0;
    if (sdkInt > 28) return;
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      throw DownloadsException(
        status.isPermanentlyDenied
            ? 'Storage permission is blocked. Enable it in system settings '
                'to export.'
            : 'Storage permission is needed to save to Downloads.',
      );
    }
  }

  String _messageFor(PlatformException e) => switch (e.code) {
        'NO_STORAGE' => 'Downloads folder is not available.',
        'PERMISSION' => 'Permission denied while saving the file.',
        _ => 'Could not save the file${e.message == null ? '' : ': ${e.message}'}',
      };
}
