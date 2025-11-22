import 'package:test/test.dart';

import 'analyzer_output.dart';
import 'matchers.dart';

void main() {
  group('containsLintErrors matcher', () {
    test('matches when file has all specified diagnostics (non-exclusive)', () {
      final d1 = LintDiagnostic(
        line: 2,
        col: 1,
        message: 'Err A',
        code: 'import_rule_violation',
      );
      final d2 = LintDiagnostic(
        line: 3,
        col: 1,
        message: 'Err B',
        code: 'import_rule_violation',
      );
      final output = AnalyzerOutput([
        LintError(file: 'lib/a.dart', diagnostic: d1),
        LintError(file: 'lib/a.dart', diagnostic: d2),
        // other file error should not affect
        LintError(
          file: 'lib/other.dart',
          diagnostic: LintDiagnostic(
            line: 10,
            col: 1,
            message: 'Other',
            code: 'import_rule_violation',
          ),
        ),
      ]);
      expect(
        output,
        containsLintErrors(file: 'lib/a.dart', diagnostics: [d1, d2]),
      );
    });
    test('does not match when one of the specified diagnostics is missing', () {
      final d1 = LintDiagnostic(
        line: 2,
        col: 1,
        message: 'Err A',
        code: 'import_rule_violation',
      );
      final d2 = LintDiagnostic(
        line: 3,
        col: 1,
        message: 'Err B',
        code: 'import_rule_violation',
      );
      final output = AnalyzerOutput([
        LintError(file: 'lib/a.dart', diagnostic: d1),
      ]);
      expect(
        output,
        isNot(containsLintErrors(file: 'lib/a.dart', diagnostics: [d1, d2])),
      );
    });
    test(
      'non-exclusive matches even if extra diagnostics exist for the file',
      () {
        final d1 = LintDiagnostic(
          line: 2,
          col: 1,
          message: 'Err A',
          code: 'import_rule_violation',
        );
        final d2 = LintDiagnostic(
          line: 3,
          col: 1,
          message: 'Err B',
          code: 'import_rule_violation',
        );
        final extra = LintDiagnostic(
          line: 4,
          col: 1,
          message: 'Extra',
          code: 'import_rule_violation',
        );
        final output = AnalyzerOutput([
          LintError(file: 'lib/a.dart', diagnostic: d1),
          LintError(file: 'lib/a.dart', diagnostic: d2),
          LintError(file: 'lib/a.dart', diagnostic: extra),
        ]);
        expect(
          output,
          containsLintErrors(file: 'lib/a.dart', diagnostics: [d1, d2]),
        );
      },
    );
    test('exclusive matches only when exactly specified diagnostics exist', () {
      final d1 = LintDiagnostic(
        line: 2,
        col: 1,
        message: 'Err A',
        code: 'import_rule_violation',
      );
      final d2 = LintDiagnostic(
        line: 3,
        col: 1,
        message: 'Err B',
        code: 'import_rule_violation',
      );
      final output = AnalyzerOutput([
        LintError(file: 'lib/a.dart', diagnostic: d1),
        LintError(file: 'lib/a.dart', diagnostic: d2),
      ]);
      expect(
        output,
        containsLintErrors(
          file: 'lib/a.dart',
          diagnostics: [d1, d2],
          exclusive: true,
        ),
      );
    });
    test('exclusive does not match when extra diagnostics exist', () {
      final d1 = LintDiagnostic(
        line: 2,
        col: 1,
        message: 'Err A',
        code: 'import_rule_violation',
      );
      final d2 = LintDiagnostic(
        line: 3,
        col: 1,
        message: 'Err B',
        code: 'import_rule_violation',
      );
      final extra = LintDiagnostic(
        line: 4,
        col: 1,
        message: 'Extra',
        code: 'import_rule_violation',
      );
      final output = AnalyzerOutput([
        LintError(file: 'lib/a.dart', diagnostic: d1),
        LintError(file: 'lib/a.dart', diagnostic: d2),
        LintError(file: 'lib/a.dart', diagnostic: extra),
      ]);
      expect(
        output,
        isNot(
          containsLintErrors(
            file: 'lib/a.dart',
            diagnostics: [d1, d2],
            exclusive: true,
          ),
        ),
      );
    });
    test('respects multiplicity of the same diagnostic', () {
      final d = LintDiagnostic(
        line: 2,
        col: 1,
        message: 'Duplicate',
        code: 'import_rule_violation',
      );
      final output = AnalyzerOutput([
        LintError(file: 'lib/a.dart', diagnostic: d),
        LintError(file: 'lib/a.dart', diagnostic: d),
      ]);
      expect(
        output,
        containsLintErrors(
          file: 'lib/a.dart',
          diagnostics: [d, d],
          exclusive: true,
        ),
      );
    });
    test('fails when requested multiplicity exceeds present occurrences', () {
      final d = LintDiagnostic(
        line: 2,
        col: 1,
        message: 'Duplicate',
        code: 'import_rule_violation',
      );
      final output = AnalyzerOutput([
        LintError(file: 'lib/a.dart', diagnostic: d),
      ]);
      expect(
        output,
        isNot(containsLintErrors(file: 'lib/a.dart', diagnostics: [d, d])),
      );
    });
    test('does not match diagnostics on a different file', () {
      final d = LintDiagnostic(
        line: 2,
        col: 1,
        message: 'Err A',
        code: 'import_rule_violation',
      );
      final output = AnalyzerOutput([
        LintError(file: 'lib/other.dart', diagnostic: d),
      ]);
      expect(
        output,
        isNot(containsLintErrors(file: 'lib/a.dart', diagnostics: [d])),
      );
    });
    test('compares message and code exactly', () {
      final expected = LintDiagnostic(
        line: 2,
        col: 1,
        message: 'Exact message',
        code: 'import_rule_violation',
      );
      final differentCode = LintDiagnostic(
        line: 2,
        col: 1,
        message: 'Exact message',
        code: 'different_code',
      );
      final output = AnalyzerOutput([
        LintError(file: 'lib/a.dart', diagnostic: differentCode),
      ]);
      expect(
        output,
        isNot(containsLintErrors(file: 'lib/a.dart', diagnostics: [expected])),
      );
    });
  });
  group('containsAnyLintErrors matcher', () {
    test('matches when any error exists for the file', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/domain/domain.dart',
          diagnostic: LintDiagnostic(
            line: 2,
            col: 1,
            message: 'Err at line 2',
            code: 'import_rule_violation',
          ),
        ),
        LintError(
          file: 'lib/other.dart',
          diagnostic: LintDiagnostic(
            line: 10,
            col: 1,
            message: 'Other file error',
            code: 'import_rule_violation',
          ),
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
            diagnostic: LintDiagnostic(
              line: 2,
              col: 1,
              message: 'Err at line 2',
              code: 'import_rule_violation',
            ),
          ),
          LintError(
            file: 'lib/domain/domain.dart',
            diagnostic: LintDiagnostic(
              line: 3,
              col: 1,
              message: 'Err at line 3',
              code: 'import_rule_violation',
            ),
          ),
          LintError(
            file: 'lib/domain/domain.dart',
            diagnostic: LintDiagnostic(
              line: 4,
              col: 1,
              message: 'Err at line 4',
              code: 'import_rule_violation',
            ),
          ),
        ]);

        expect(output, containsAnyLintErrors(file: 'lib/domain/domain.dart'));
      },
    );

    test('does not match when the file has no errors', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/feature/a.dart',
          diagnostic: LintDiagnostic(
            line: 1,
            col: 1,
            message: 'Some error',
            code: 'import_rule_violation',
          ),
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
          diagnostic: LintDiagnostic(
            line: 2,
            col: 1,
            message: 'Some other lint code',
            code: 'some_other_code',
          ),
        ),
      ]);

      expect(output, containsAnyLintErrors(file: 'lib/domain/domain.dart'));
    });
    test('matches when all specified lines have errors', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/domain/domain.dart',
          diagnostic: LintDiagnostic(
            line: 2,
            col: 1,
            message: 'Err at line 2',
            code: 'import_rule_violation',
          ),
        ),
        LintError(
          file: 'lib/domain/domain.dart',
          diagnostic: LintDiagnostic(
            line: 3,
            col: 1,
            message: 'Err at line 3',
            code: 'import_rule_violation',
          ),
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
          diagnostic: LintDiagnostic(
            line: 2,
            col: 1,
            message: 'Err at line 2',
            code: 'import_rule_violation',
          ),
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
          diagnostic: LintDiagnostic(
            line: 5,
            col: 1,
            message: 'Err at line 5',
            code: 'import_rule_violation',
          ),
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
          diagnostic: LintDiagnostic(
            line: 2,
            col: 1,
            message: 'Err at line 2',
            code: 'import_rule_violation',
          ),
        ),
        LintError(
          file: 'lib/domain/domain.dart',
          diagnostic: LintDiagnostic(
            line: 3,
            col: 1,
            message: 'Err at line 3',
            code: 'import_rule_violation',
          ),
        ),
        LintError(
          file: 'lib/domain/domain.dart',
          diagnostic: LintDiagnostic(
            line: 4,
            col: 1,
            message: 'Extra err at line 4',
            code: 'import_rule_violation',
          ),
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
          diagnostic: LintDiagnostic(
            line: 2,
            col: 1,
            message: 'Err at line 2',
            code: 'import_rule_violation',
          ),
        ),
        LintError(
          file: 'lib/domain/domain.dart',
          diagnostic: LintDiagnostic(
            line: 3,
            col: 1,
            message: 'Err at line 3',
            code: 'import_rule_violation',
          ),
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
          diagnostic: LintDiagnostic(
            line: 2,
            col: 1,
            message: 'Err at line 2',
            code: 'import_rule_violation',
          ),
        ),
        LintError(
          file: 'lib/domain/domain.dart',
          diagnostic: LintDiagnostic(
            line: 3,
            col: 1,
            message: 'Err at line 3',
            code: 'import_rule_violation',
          ),
        ),
        LintError(
          file: 'lib/domain/domain.dart',
          diagnostic: LintDiagnostic(
            line: 4,
            col: 1,
            message: 'Extra err at line 4',
            code: 'import_rule_violation',
          ),
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
