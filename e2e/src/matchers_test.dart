import 'package:test/test.dart';

import 'analyzer_output.dart';
import 'matchers.dart';

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
  group('containsAnyLintErrors matcher', () {
    test('matches when any error exists for the file', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/domain/domain.dart',
          line: 2,
          col: 1,
          message: 'Err at line 2',
          code: 'import_rule_violation',
        ),
        LintError(
          file: 'lib/other.dart',
          line: 10,
          col: 1,
          message: 'Other file error',
          code: 'import_rule_violation',
        ),
      ]);

      expect(output, containsAnyLintErrors(file: 'lib/domain/domain.dart'));
    });

    test(
      'matches when multiple errors exist for the file on different lines',
      () {
        final output = AnalyzerOutput([
          LintError(
            file: 'lib/domain/domain.dart',
            line: 2,
            col: 1,
            message: 'Err at line 2',
            code: 'import_rule_violation',
          ),
          LintError(
            file: 'lib/domain/domain.dart',
            line: 3,
            col: 1,
            message: 'Err at line 3',
            code: 'import_rule_violation',
          ),
          LintError(
            file: 'lib/domain/domain.dart',
            line: 4,
            col: 1,
            message: 'Err at line 4',
            code: 'import_rule_violation',
          ),
        ]);

        expect(output, containsAnyLintErrors(file: 'lib/domain/domain.dart'));
      },
    );

    test('does not match when the file has no errors', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/feature/a.dart',
          line: 1,
          col: 1,
          message: 'Some error',
          code: 'import_rule_violation',
        ),
      ]);

      expect(
        output,
        isNot(containsAnyLintErrors(file: 'lib/domain/domain.dart')),
      );
    });

    test('does not match when output is empty', () {
      final output = AnalyzerOutput([]);

      expect(
        output,
        isNot(containsAnyLintErrors(file: 'lib/domain/domain.dart')),
      );
    });

    test('matches regardless of lint code', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/domain/domain.dart',
          line: 2,
          col: 1,
          message: 'Some other lint code',
          code: 'some_other_code',
        ),
      ]);

      expect(output, containsAnyLintErrors(file: 'lib/domain/domain.dart'));
    });
    test('matches when all specified lines have errors', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/domain/domain.dart',
          line: 2,
          col: 1,
          message: 'Err at line 2',
          code: 'import_rule_violation',
        ),
        LintError(
          file: 'lib/domain/domain.dart',
          line: 3,
          col: 1,
          message: 'Err at line 3',
          code: 'import_rule_violation',
        ),
      ]);

      expect(
        output,
        containsAnyLintErrors(file: 'lib/domain/domain.dart', lines: [2, 3]),
      );
    });
    test('does not match when only some specified lines have errors', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/domain/domain.dart',
          line: 2,
          col: 1,
          message: 'Err at line 2',
          code: 'import_rule_violation',
        ),
      ]);

      expect(
        output,
        isNot(
          containsAnyLintErrors(file: 'lib/domain/domain.dart', lines: [2, 3]),
        ),
      );
    });
    test('does not match when specified lines have no errors', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/domain/domain.dart',
          line: 5,
          col: 1,
          message: 'Err at line 5',
          code: 'import_rule_violation',
        ),
      ]);

      expect(
        output,
        isNot(
          containsAnyLintErrors(
            file: 'lib/domain/domain.dart',
            lines: [1, 2, 3],
          ),
        ),
      );
    });
    test('non-exclusive matches even if extra error lines exist', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/domain/domain.dart',
          line: 2,
          col: 1,
          message: 'Err at line 2',
          code: 'import_rule_violation',
        ),
        LintError(
          file: 'lib/domain/domain.dart',
          line: 3,
          col: 1,
          message: 'Err at line 3',
          code: 'import_rule_violation',
        ),
        LintError(
          file: 'lib/domain/domain.dart',
          line: 4,
          col: 1,
          message: 'Extra err at line 4',
          code: 'import_rule_violation',
        ),
      ]);

      expect(
        output,
        containsAnyLintErrors(file: 'lib/domain/domain.dart', lines: [2, 3]),
      );
    });
    test('exclusive matches only when exactly specified lines have errors', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/domain/domain.dart',
          line: 2,
          col: 1,
          message: 'Err at line 2',
          code: 'import_rule_violation',
        ),
        LintError(
          file: 'lib/domain/domain.dart',
          line: 3,
          col: 1,
          message: 'Err at line 3',
          code: 'import_rule_violation',
        ),
      ]);

      expect(
        output,
        containsAnyLintErrors(
          file: 'lib/domain/domain.dart',
          lines: [2, 3],
          exclusive: true,
        ),
      );
    });
    test('exclusive does not match when extra error lines exist', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/domain/domain.dart',
          line: 2,
          col: 1,
          message: 'Err at line 2',
          code: 'import_rule_violation',
        ),
        LintError(
          file: 'lib/domain/domain.dart',
          line: 3,
          col: 1,
          message: 'Err at line 3',
          code: 'import_rule_violation',
        ),
        LintError(
          file: 'lib/domain/domain.dart',
          line: 4,
          col: 1,
          message: 'Extra err at line 4',
          code: 'import_rule_violation',
        ),
      ]);

      expect(
        output,
        isNot(
          containsAnyLintErrors(
            file: 'lib/domain/domain.dart',
            lines: [2, 3],
            exclusive: true,
          ),
        ),
      );
    });
  });
}
