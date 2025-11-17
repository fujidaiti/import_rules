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
