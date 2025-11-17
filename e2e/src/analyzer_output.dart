/// Represents the parsed output from dart analyze command
class AnalyzerOutput {
  final List<LintError> errors;

  AnalyzerOutput(this.errors);

  static AnalyzerOutput parse(String output) {
    final errors = <LintError>[];
    // Parse format: "   info - lib/main.dart:5:1 - Message - code"
    final regex = RegExp(
      r'^\s+\w+ - ([^:]+):(\d+):(\d+) - (.+?) - (\w+)$',
      multiLine: true,
    );

    for (final match in regex.allMatches(output)) {
      errors.add(
        LintError(
          file: match.group(1)!,
          line: int.parse(match.group(2)!),
          col: int.parse(match.group(3)!),
          message: match.group(4)!,
          code: match.group(5)!,
        ),
      );
    }

    return AnalyzerOutput(errors);
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

/// Represents a single lint error from analyzer output
class LintError {
  final String file;
  final int line;
  final int col;
  final String message;
  final String code;

  LintError({
    required this.file,
    required this.line,
    required this.col,
    required this.message,
    required this.code,
  });

  @override
  String toString() => '$file:$line:$col - $message ($code)';
}
