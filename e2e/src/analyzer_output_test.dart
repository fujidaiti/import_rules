import 'package:test/test.dart';

import 'analyzer_output.dart';

void main() {
  group('AnalyzerOutput.parse', () {
    test('parses single error correctly', () {
      final output = '''
Analyzing test_project...

   info - lib/main.dart:5:1 - Import rule violation. Do not import this. - import_rule_violation

1 issue found.
''';

      final result = AnalyzerOutput.parse(output);

      expect(result.errors.length, 1);
      expect(result.errors[0].file, 'lib/main.dart');
      expect(result.errors[0].diagnostic.line, 5);
      expect(result.errors[0].diagnostic.col, 1);
      expect(
        result.errors[0].diagnostic.message,
        'Import rule violation. Do not import this.',
      );
      expect(result.errors[0].diagnostic.code, 'import_rule_violation');
    });

    test('parses multiple errors correctly', () {
      final output = '''
Analyzing test_project...

   info - lib/main.dart:5:1 - Import rule violation. First error. - import_rule_violation
   info - lib/other.dart:10:8 - Import rule violation. Second error. - import_rule_violation

2 issues found.
''';

      final result = AnalyzerOutput.parse(output);

      expect(result.errors.length, 2);

      expect(result.errors[0].file, 'lib/main.dart');
      expect(result.errors[0].diagnostic.line, 5);
      expect(result.errors[0].diagnostic.col, 1);

      expect(result.errors[1].file, 'lib/other.dart');
      expect(result.errors[1].diagnostic.line, 10);
      expect(result.errors[1].diagnostic.col, 8);
    });

    test('returns empty list when no errors', () {
      final output = '''
Analyzing test_project...

No issues found.
''';

      final result = AnalyzerOutput.parse(output);

      expect(result.errors, isEmpty);
    });

    test('handles nested file paths', () {
      final output = '''
   info - lib/features/auth/src/utils.dart:15:1 - Import rule violation. Message. - import_rule_violation
''';

      final result = AnalyzerOutput.parse(output);

      expect(result.errors.length, 1);
      expect(result.errors[0].file, 'lib/features/auth/src/utils.dart');
      expect(result.errors[0].diagnostic.line, 15);
    });

    test('ignores non-error lines', () {
      final output = '''
Analyzing test_project...

Some other output line
   info - lib/main.dart:5:1 - Import rule violation. Message. - import_rule_violation
Another line of output

1 issue found.
''';

      final result = AnalyzerOutput.parse(output);

      expect(result.errors.length, 1);
      expect(result.errors[0].file, 'lib/main.dart');
    });

    test('handles different severity levels', () {
      final output = '''
   warning - lib/main.dart:5:1 - Import rule violation. Message. - import_rule_violation
   error - lib/other.dart:10:1 - Import rule violation. Message. - import_rule_violation
''';

      final result = AnalyzerOutput.parse(output);

      expect(result.errors.length, 2);
    });
  });

  group('LintError.toString', () {
    test('formats error correctly', () {
      final error = LintError(
        file: 'lib/main.dart',
        diagnostic: LintDiagnostic(
          line: 5,
          col: 1,
          message: 'Import rule violation.',
          code: 'import_rule_violation',
        ),
      );

      expect(
        error.toString(),
        'lib/main.dart:5:1 - Import rule violation. (import_rule_violation)',
      );
    });
  });

  group('AnalyzerOutput.toString', () {
    test('formats output with no errors', () {
      final output = AnalyzerOutput([]);

      expect(output.toString(), 'AnalyzerOutput(no errors)');
    });

    test('formats output with single error', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/main.dart',
          diagnostic: LintDiagnostic(
            line: 5,
            col: 1,
            message: 'Import rule violation.',
            code: 'import_rule_violation',
          ),
        ),
      ]);

      expect(
        output.toString(),
        'AnalyzerOutput(1 error):\n'
        '  - lib/main.dart:5:1 - Import rule violation. (import_rule_violation)',
      );
    });

    test('formats output with multiple errors', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/main.dart',
          diagnostic: LintDiagnostic(
            line: 5,
            col: 1,
            message: 'First error.',
            code: 'import_rule_violation',
          ),
        ),
        LintError(
          file: 'lib/other.dart',
          diagnostic: LintDiagnostic(
            line: 10,
            col: 8,
            message: 'Second error.',
            code: 'import_rule_violation',
          ),
        ),
      ]);

      expect(
        output.toString(),
        'AnalyzerOutput(2 errors):\n'
        '  - lib/main.dart:5:1 - First error. (import_rule_violation)\n'
        '  - lib/other.dart:10:8 - Second error. (import_rule_violation)',
      );
    });
  });
}
