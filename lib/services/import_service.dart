import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../data/weight_repository.dart';
import '../domain/csv_codec.dart';

/// Summary shown after an import.
class ImportSummary {
  const ImportSummary({
    required this.imported,
    required this.duplicates,
    required this.invalid,
  });

  final int imported;
  final int duplicates;
  final int invalid;
}

/// A user-facing failure while importing.
class ImportException implements Exception {
  const ImportException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Lets the user pick a CSV file and merges its entries into the database.
class ImportService {
  ImportService(this._repository);

  final WeightRepository _repository;

  /// Picks and imports a CSV file. Returns `null` if the user cancelled.
  ///
  /// Throws [ImportException] with a readable message on failure.
  Future<ImportSummary?> pickAndImport() async {
    final file = await _pickCsv();
    if (file == null) return null;

    if ((file.extension ?? '').toLowerCase() != 'csv') {
      throw const ImportException('Please choose a .csv file.');
    }

    final String text;
    try {
      text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    } catch (_) {
      throw const ImportException('Could not read the selected file.');
    }

    final CsvDecodeResult decoded;
    try {
      decoded = decodeEntries(text);
    } on CsvHeaderException catch (e) {
      throw ImportException(e.message);
    } catch (_) {
      throw const ImportException('The file is not a valid CSV.');
    }

    final counts = await _repository.insertAllIgnoringDuplicates(
      decoded.entries,
    );
    return ImportSummary(
      imported: counts.inserted,
      duplicates: counts.duplicates,
      invalid: decoded.invalidRows,
    );
  }

  /// Tries a CSV-filtered picker first; some devices mishandle CSV MIME
  /// types, so fall back to any file (the extension is checked afterwards).
  Future<PlatformFile?> _pickCsv() async {
    try {
      return await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
    } catch (_) {
      return FilePicker.pickFile(type: FileType.any);
    }
  }
}
