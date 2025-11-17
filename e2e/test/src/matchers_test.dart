import 'package:test/test.dart';
import '../../src/analyzer_output.dart';
import '../../src/matchers.dart';

void main() {
  group('containsLintError matcher', () {
    test('matches when error exists with exact file, line, and col', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/main.dart',
          line: 5,
          col: 1,
          message: 'Import rule violation. Do not import this.',
          code: 'import_rule_violation',
        ),
      ]);

      expect(output, containsLintError(file: 'lib/main.dart', line: 5, col: 1));
    });

    test('matches when error exists with file only', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/main.dart',
          line: 5,
          col: 1,
          message: 'Import rule violation.',
          code: 'import_rule_violation',
        ),
      ]);

      expect(output, containsLintError(file: 'lib/main.dart'));
    });

    test('matches when error exists with file and line only', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/main.dart',
          line: 5,
          col: 1,
          message: 'Import rule violation.',
          code: 'import_rule_violation',
        ),
      ]);

      expect(output, containsLintError(file: 'lib/main.dart', line: 5));
    });

    test('matches when message contains expected text', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/main.dart',
          line: 5,
          col: 1,
          message:
              'Import rule violation. Presentation layer should not import data layer.',
          code: 'import_rule_violation',
        ),
      ]);

      expect(
        output,
        containsLintError(
          file: 'lib/main.dart',
          message: contains('Presentation layer should not import data layer'),
        ),
      );
    });

    test('does not match when file is different', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/main.dart',
          line: 5,
          col: 1,
          message: 'Import rule violation.',
          code: 'import_rule_violation',
        ),
      ]);

      expect(output, isNot(containsLintError(file: 'lib/other.dart')));
    });

    test('does not match when line is different', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/main.dart',
          line: 5,
          col: 1,
          message: 'Import rule violation.',
          code: 'import_rule_violation',
        ),
      ]);

      expect(output, isNot(containsLintError(file: 'lib/main.dart', line: 10)));
    });

    test('does not match when col is different', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/main.dart',
          line: 5,
          col: 1,
          message: 'Import rule violation.',
          code: 'import_rule_violation',
        ),
      ]);

      expect(
        output,
        isNot(containsLintError(file: 'lib/main.dart', line: 5, col: 8)),
      );
    });

    test('does not match when message does not contain expected text', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/main.dart',
          line: 5,
          col: 1,
          message: 'Import rule violation. Some other reason.',
          code: 'import_rule_violation',
        ),
      ]);

      expect(
        output,
        isNot(
          containsLintError(
            file: 'lib/main.dart',
            message: contains('expected text not present'),
          ),
        ),
      );
    });

    test('matches one of multiple errors', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/main.dart',
          line: 5,
          col: 1,
          message: 'First error',
          code: 'import_rule_violation',
        ),
        LintError(
          file: 'lib/other.dart',
          line: 10,
          col: 1,
          message: 'Second error',
          code: 'import_rule_violation',
        ),
      ]);

      expect(output, containsLintError(file: 'lib/other.dart', line: 10));
    });

    test('does not match when output is empty', () {
      final output = AnalyzerOutput([]);

      expect(output, isNot(containsLintError(file: 'lib/main.dart')));
    });
  });
}
