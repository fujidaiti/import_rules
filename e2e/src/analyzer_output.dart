/// Represents the parsed output from dart analyze command
class AnalyzerOutput {
  final List<LintError> errors;

  AnalyzerOutput(this.errors);

  static AnalyzerOutput parse(String output) {
    final errors = <LintError>[];
    // Parse format: "  severity - lib/main.dart:5:1 - Message - code"
    // Note: leading whitespace is optional as some Dart SDK versions omit it.
    final regex = RegExp(
      r'^\s*(\w+) - ([^:]+):(\d+):(\d+) - (.+?) - (\w+)$',
      multiLine: true,
    );

    for (final match in regex.allMatches(output)) {
      final diagnostic = LintDiagnostic(
        severity: match.group(1)!,
        line: int.parse(match.group(3)!),
        col: int.parse(match.group(4)!),
        message: match.group(5)!,
        code: match.group(6)!,
      );
      errors.add(LintError(file: match.group(2)!, diagnostic: diagnostic));
    }

    return AnalyzerOutput(List.unmodifiable(errors));
  }

  @override
  String toString() {
    if (errors.isEmpty) {
      return 'AnalyzerOutput(no errors)';
    }
    final errorList = errors.map((e) => '  - $e').join('\n');
    return 'AnalyzerOutput(${errors.length} error${errors.length == 1 ? '' : 's'}):\n$errorList';
  }
}

/// Represents diagnostic details for a lint error
class LintDiagnostic {
  final String? severity;
  final int line;
  final int col;
  final String message;
  final String code;

  LintDiagnostic({
    this.severity,
    required this.line,
    required this.col,
    required this.message,
    required this.code,
  });
}

/// Represents a single lint error from analyzer output
class LintError {
  final String file;
  final LintDiagnostic diagnostic;

  LintError({required this.file, required this.diagnostic});

  @override
  String toString() =>
      '$file:${diagnostic.line}:${diagnostic.col} - ${diagnostic.message} (${diagnostic.code})';
}
