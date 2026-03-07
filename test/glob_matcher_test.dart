import 'package:glob/glob.dart' as glob_pkg;
import 'package:import_rules/src/glob_matcher.dart';
import 'package:test/test.dart';

void main() {
  /// Helper function to test both implementations match
  void expectBothMatch(String pattern, String path, bool shouldMatch) {
    final globResult = glob_pkg.Glob(pattern).matches(path);
    final customResult = GlobMatcher(pattern).matches(path);

    expect(
      globResult,
      shouldMatch,
      reason:
          'glob package should ${shouldMatch ? "match" : "not match"} "$pattern" against "$path"',
    );
    expect(
      customResult,
      shouldMatch,
      reason:
          'GlobMatcher should ${shouldMatch ? "match" : "not match"} "$pattern" against "$path"',
    );
    expect(
      customResult,
      globResult,
      reason:
          'GlobMatcher must match glob package behavior for pattern "$pattern" against path "$path"',
    );
  }

  group('Literal paths (no wildcards)', () {
    test('matches exact path', () {
      expectBothMatch('lib/main.dart', 'lib/main.dart', true);
    });

    test('does not match different path', () {
      expectBothMatch('lib/main.dart', 'lib/app.dart', false);
    });

    test('does not match partial path', () {
      expectBothMatch('lib/main.dart', 'lib/main', false);
    });

    test('does not match with extra segments', () {
      expectBothMatch('lib/main.dart', 'lib/src/main.dart', false);
    });
  });

  group('Single asterisk (*) - no directory crossing', () {
    test('matches files in same directory', () {
      expectBothMatch('lib/*.dart', 'lib/app.dart', true);
      expectBothMatch('lib/*.dart', 'lib/main.dart', true);
    });

    test('does NOT match files in subdirectories', () {
      expectBothMatch('lib/*.dart', 'lib/features/auth.dart', false);
      expectBothMatch('lib/*.dart', 'lib/src/app.dart', false);
    });

    test('matches zero characters', () {
      expectBothMatch('lib/*.dart', 'lib/.dart', true);
    });

    test('works in middle of pattern', () {
      expectBothMatch('lib/*/service.dart', 'lib/auth/service.dart', true);
      expectBothMatch('lib/*/service.dart', 'lib/user/service.dart', true);
    });

    test('does NOT match nested paths in middle pattern', () {
      expectBothMatch(
        'lib/*/service.dart',
        'lib/features/auth/service.dart',
        false,
      );
    });

    test('works at start of pattern', () {
      expectBothMatch('*/main.dart', 'lib/main.dart', true);
      expectBothMatch('*/main.dart', 'test/main.dart', true);
    });

    test('does NOT match multiple segments at start', () {
      expectBothMatch('*/main.dart', 'lib/src/main.dart', false);
    });

    test('works at end of pattern', () {
      expectBothMatch('lib/src/*', 'lib/src/app.dart', true);
      expectBothMatch('lib/src/*', 'lib/src/utils.dart', true);
    });

    test('multiple asterisks in pattern', () {
      expectBothMatch('lib/src/*.g.dart', 'lib/src/user.g.dart', true);
      expectBothMatch('lib/src/*.g.dart', 'lib/src/auth.g.dart', true);
    });

    test('does NOT match slash character', () {
      expectBothMatch('lib/*.dart', 'lib/src/app.dart', false);
    });
  });

  group('Double asterisk (**) - recursive matching', () {
    test('matches files at any depth', () {
      expectBothMatch('lib/**', 'lib/app.dart', true);
      expectBothMatch('lib/**', 'lib/src/app.dart', true);
      expectBothMatch('lib/**', 'lib/features/auth/user.dart', true);
    });

    test('matches zero segments', () {
      expectBothMatch('lib/**', 'lib/app.dart', true);
    });

    test('matches directories', () {
      expectBothMatch('lib/**', 'lib/src', true);
      expectBothMatch('lib/**', 'lib/features/auth', true);
    });

    test('works with specific filename', () {
      expectBothMatch('lib/**/service.dart', 'lib/service.dart', false);
      expectBothMatch('lib/**/service.dart', 'lib/auth/service.dart', true);
      expectBothMatch(
        'lib/**/service.dart',
        'lib/features/auth/service.dart',
        true,
      );
    });

    test('works at start of pattern', () {
      expectBothMatch('**/src/**', 'lib/src/app.dart', true);
      expectBothMatch('**/src/**', 'features/auth/src/user.dart', true);
      expectBothMatch('**/src/**', 'src/main.dart', false);
    });

    test('works in middle of pattern', () {
      expectBothMatch('lib/**/src/**', 'lib/src/app.dart', false);
      expectBothMatch('lib/**/src/**', 'lib/features/src/auth.dart', true);
      expectBothMatch('lib/**/src/**', 'lib/features/auth/src/user.dart', true);
    });

    test('matches files with extension at any depth', () {
      expectBothMatch('lib/**.g.dart', 'lib/app.g.dart', true);
      expectBothMatch('lib/**.g.dart', 'lib/src/user.g.dart', true);
      expectBothMatch('lib/**.g.dart', 'lib/features/auth/dto.g.dart', true);
    });

    test('does NOT match different extension', () {
      expectBothMatch('lib/**.g.dart', 'lib/app.dart', false);
      expectBothMatch('lib/**.g.dart', 'lib/src/user.freezed.dart', false);
    });

    test('does NOT match outside base directory', () {
      expectBothMatch('lib/**', 'test/app.dart', false);
      expectBothMatch('lib/**', 'src/main.dart', false);
    });
  });

  group('Real patterns from import_rules tests', () {
    group('lib/**', () {
      test('matches files in lib at any depth', () {
        expectBothMatch('lib/**', 'lib/main.dart', true);
        expectBothMatch('lib/**', 'lib/src/app.dart', true);
        expectBothMatch('lib/**', 'lib/features/auth/user.dart', true);
      });

      test('does not match outside lib', () {
        expectBothMatch('lib/**', 'test/main.dart', false);
        expectBothMatch('lib/**', 'src/app.dart', false);
      });
    });

    group('lib/*.dart', () {
      test('matches dart files in lib only', () {
        expectBothMatch('lib/*.dart', 'lib/main.dart', true);
        expectBothMatch('lib/*.dart', 'lib/app.dart', true);
      });

      test('does not match subdirectories', () {
        expectBothMatch('lib/*.dart', 'lib/src/app.dart', false);
      });
    });

    group('lib/*/service.dart', () {
      test('matches service.dart one level deep', () {
        expectBothMatch('lib/*/service.dart', 'lib/auth/service.dart', true);
        expectBothMatch('lib/*/service.dart', 'lib/user/service.dart', true);
      });

      test('does not match deeper nesting', () {
        expectBothMatch(
          'lib/*/service.dart',
          'lib/features/auth/service.dart',
          false,
        );
      });
    });

    group('lib/**/service.dart', () {
      test('matches service.dart at any depth (except immediate)', () {
        expectBothMatch('lib/**/service.dart', 'lib/service.dart', false);
        expectBothMatch('lib/**/service.dart', 'lib/auth/service.dart', true);
        expectBothMatch(
          'lib/**/service.dart',
          'lib/features/auth/service.dart',
          true,
        );
      });
    });

    group('**/src/**', () {
      test('matches any src directory anywhere (with nesting)', () {
        expectBothMatch('**/src/**', 'src/main.dart', false);
        expectBothMatch('**/src/**', 'lib/src/app.dart', true);
        expectBothMatch('**/src/**', 'features/auth/src/user.dart', true);
      });

      test('does not match non-src paths', () {
        expectBothMatch('**/src/**', 'lib/main.dart', false);
        expectBothMatch('**/src/**', 'test/app_test.dart', false);
      });
    });

    group('lib/src/**/*.dart', () {
      test('matches dart files recursively in lib/src (nested)', () {
        expectBothMatch('lib/src/**/*.dart', 'lib/src/app.dart', false);
        expectBothMatch('lib/src/**/*.dart', 'lib/src/utils/helper.dart', true);
      });

      test('does not match outside lib/src', () {
        expectBothMatch('lib/src/**/*.dart', 'lib/main.dart', false);
        expectBothMatch('lib/src/**/*.dart', 'test/src/app.dart', false);
      });
    });

    group('lib/**.g.dart', () {
      test('matches generated files at any depth in lib', () {
        expectBothMatch('lib/**.g.dart', 'lib/app.g.dart', true);
        expectBothMatch('lib/**.g.dart', 'lib/src/user.g.dart', true);
        expectBothMatch('lib/**.g.dart', 'lib/models/dto/user.g.dart', true);
      });

      test('does not match non-generated files', () {
        expectBothMatch('lib/**.g.dart', 'lib/app.dart', false);
        expectBothMatch('lib/**.g.dart', 'lib/src/user.freezed.dart', false);
      });
    });

    group('lib/**.freezed.dart', () {
      test('matches freezed files at any depth in lib', () {
        expectBothMatch('lib/**.freezed.dart', 'lib/app.freezed.dart', true);
        expectBothMatch(
          'lib/**.freezed.dart',
          'lib/src/user.freezed.dart',
          true,
        );
      });
    });

    group('test/**', () {
      test('matches test files at any depth', () {
        expectBothMatch('test/**', 'test/app_test.dart', true);
        expectBothMatch('test/**', 'test/unit/user_test.dart', true);
      });
    });
  });

  group('Edge cases', () {
    test('empty path does not match non-empty pattern', () {
      expectBothMatch('lib/**', '', false);
    });

    test('pattern with trailing slash', () {
      // Note: GlobMatcher differs from glob package here - it matches lib/ against lib/
      // This is an edge case not used in import_rules patterns
      expectBothMatch('lib/', 'lib/main.dart', false);
    });

    test('path with leading slash (absolute-like)', () {
      expectBothMatch('/lib/**', '/lib/main.dart', true);
      expectBothMatch('/lib/**', 'lib/main.dart', false);
    });

    test('pattern with dots in filename', () {
      expectBothMatch('lib/*.test.dart', 'lib/app.test.dart', true);
      expectBothMatch('lib/*.test.dart', 'lib/src/app.test.dart', false);
    });

    test('pattern with multiple dots', () {
      expectBothMatch('lib/**.g.part.dart', 'lib/app.g.part.dart', true);
      expectBothMatch('lib/**.g.part.dart', 'lib/src/user.g.part.dart', true);
    });

    test('pattern matching directory names', () {
      expectBothMatch('lib/src', 'lib/src', true);
      expectBothMatch('lib/src', 'lib/src/app.dart', false);
    });

    test('** at end without trailing content', () {
      expectBothMatch('lib/**', 'lib/', false);
    });

    test('** at start without leading content', () {
      expectBothMatch('**/main.dart', 'main.dart', false);
      expectBothMatch('**/main.dart', 'lib/main.dart', true);
      expectBothMatch('**/main.dart', 'lib/src/main.dart', true);
    });

    test('consecutive ** patterns', () {
      expectBothMatch('lib/**/**', 'lib/main.dart', false);
      expectBothMatch('lib/**/**', 'lib/src/app.dart', true);
    });

    test('* followed by **', () {
      expectBothMatch('lib/*/**', 'lib/src/app.dart', true);
      expectBothMatch('lib/*/**', 'lib/src', false);
      expectBothMatch('lib/*/**', 'lib/main.dart', false);
    });

    test('** followed by *', () {
      expectBothMatch('lib/**/*', 'lib/main.dart', false);
      expectBothMatch('lib/**/*', 'lib/src/app.dart', true);
    });
  });

  group('Pattern caching behavior', () {
    test('same pattern instance reused', () {
      final matcher = GlobMatcher('lib/**');
      expect(matcher.matches('lib/main.dart'), true);
      expect(matcher.matches('lib/src/app.dart'), true);
      expect(matcher.matches('test/main.dart'), false);
    });

    test('different pattern instances independent', () {
      final matcher1 = GlobMatcher('lib/**');
      final matcher2 = GlobMatcher('test/**');

      expect(matcher1.matches('lib/main.dart'), true);
      expect(matcher1.matches('test/main.dart'), false);

      expect(matcher2.matches('lib/main.dart'), false);
      expect(matcher2.matches('test/main.dart'), true);
    });
  });

  group('Official glob package edge cases', () {
    group('star (*) matching empty string', () {
      test('* matches empty at end of pattern', () {
        expectBothMatch('foo*', 'foo', true);
        expectBothMatch('bar*', 'bar', true);
      });

      test('* matches empty at start of pattern', () {
        expectBothMatch('*foo', 'foo', true);
      });
    });

    group('double star (**) matching empty string', () {
      test('** matches empty when not adjacent to slash', () {
        expectBothMatch('foo**', 'foo', true);
        expectBothMatch('**bar', 'bar', true);
      });

      test('** matches single segment', () {
        expectBothMatch('**', 'a', true);
      });

      test('** matches deep nesting', () {
        expectBothMatch('**', 'a/b/c/d/e/f', true);
      });
    });

    group('double star (**) with dot-dot paths', () {
      test('matches entities containing dot-dots', () {
        expectBothMatch('**', '..foo/bar', true);
        expectBothMatch('**', 'foo../bar', true);
        expectBothMatch('**', 'foo/..bar', true);
        expectBothMatch('**', 'foo/bar..', true);
      });

      // Note: glob package rejects unresolved dot-dots like '../foo/bar'
      // GlobMatcher intentionally does NOT normalize paths - it's path-agnostic
      // In import_rules, paths from analyzer are already normalized
      test('intentional difference: does not reject unresolved dot-dots', () {
        final customResult = GlobMatcher('**').matches('../foo/bar');
        expect(
          customResult,
          true,
          reason:
              'GlobMatcher is path-agnostic and does not normalize dot-dots',
        );
      });
    });
  });
}
