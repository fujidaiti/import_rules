import 'package:test/test.dart';

import 'analyzer_output.dart';

/// Matcher that checks if analyzer output contains a specific lint error
Matcher containsLintError({
  required String file,
  int? line,
  int? col,
  Matcher? message,
}) {
  return predicate<AnalyzerOutput>(
    (output) {
      return output.errors.any(
        (error) =>
            error.file == file &&
            (line == null || error.line == line) &&
            (col == null || error.col == col) &&
            (message == null || message.matches(error.message, {})),
      );
    },
    'contains lint error in $file${line != null ? ':$line' : ''}${col != null ? ':$col' : ''}',
  );
}

/// Matcher that checks if analyzer output contains any lint errors for a file.
///
/// If [lines] is null or empty, it matches when any error exists for [file].
/// If [lines] is provided, it matches when errors exist for [file] at all of
/// the specified line numbers.
///
/// If [exclusive] is true (effective only when [lines] is provided), it matches
/// only when errors exist at all of the specified [lines] and there are no
/// additional errors for [file] at other line numbers.
Matcher containsAnyLintErrors({
  required String file,
  List<int>? lines,
  bool exclusive = false,
}) {
  assert(!exclusive || (lines != null && lines.isNotEmpty));
  return predicate<AnalyzerOutput>(
    (output) {
      if (lines == null || lines.isEmpty) {
        return output.errors.any((error) => error.file == file);
      }
      final expectedLines = lines.toSet();
      final presentLinesForFile = output.errors
          .where((error) => error.file == file)
          .map((e) => e.line)
          .toSet();
      final hasAllSpecified = expectedLines.every(presentLinesForFile.contains);
      if (!hasAllSpecified) return false;
      if (exclusive) {
        return presentLinesForFile.difference(expectedLines).isEmpty;
      }
      return true;
    },
    'contains any lint errors in $file'
    '${lines == null || lines.isEmpty
        ? ''
        : exclusive
        ? ' exactly at lines ${lines.join(', ')}'
        : ' at all of lines ${lines.join(', ')}'}',
  );
}
