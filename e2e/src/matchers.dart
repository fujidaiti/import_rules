import 'package:test/test.dart';

import 'analyzer_output.dart';

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
          .map((e) => e.diagnostic.line)
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

/// Matcher that checks if analyzer output contains all specified lint diagnostics
///
/// - Matches only when the given [file] has every diagnostic in [diagnostics]
///   present. A diagnostic is identified by equality of `line`, `col`,
///   `message`, and `code`. Duplicate diagnostics are respected; the matcher
///   requires the same multiplicity to be present.
/// - When [exclusive] is true, the file must contain exactly the specified
///   diagnostics and no additional diagnostics for that file.
Matcher containsLintErrors({
  required String file,
  required List<LintDiagnostic> diagnostics,
  bool exclusive = false,
}) {
  return predicate<AnalyzerOutput>(
    (output) {
      final remaining = output.errors
          .where((e) => e.file == file)
          .map((e) => e.diagnostic)
          .toList();
      for (final expected in diagnostics) {
        final index = remaining.indexWhere(
          (d) =>
              d.line == expected.line &&
              d.col == expected.col &&
              d.message == expected.message &&
              d.code == expected.code,
        );
        if (index == -1) return false;
        remaining.removeAt(index);
      }
      if (exclusive) {
        return remaining.isEmpty;
      }
      return true;
    },
    'contains specified lint errors in $file${exclusive ? ' exclusively' : ''}',
  );
}
