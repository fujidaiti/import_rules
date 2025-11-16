import 'package:import_rules/src/import_rules.dart';
import 'package:test/test.dart';

void main() {
  group('Target matching', () {
    test('rule does not apply when target does not match', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/features/**'],
        disallow: ['lib/data/**'],
      );

      // Rule doesn't apply to lib/core, so import is allowed
      expect(
        rule.canImport(
          'lib/core/entity.dart',
          Import(uri: 'lib/data/repo.dart'),
        ),
        isTrue,
      );
    });

    test('rule applies when target matches', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/features/**'],
        disallow: ['lib/data/**'],
      );

      // Rule applies to lib/features
      expect(
        rule.canImport(
          'lib/features/auth/login.dart',
          Import(uri: 'lib/data/repo.dart'),
        ),
        isFalse,
      );
    });

    test('target pattern with single wildcard matches single level', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/*/service.dart'],
        disallow: ['lib/data/**'],
      );

      // Matches lib/core/service.dart
      expect(
        rule.canImport(
          'lib/core/service.dart',
          Import(uri: 'lib/data/repo.dart'),
        ),
        isFalse,
      );

      // Does not match lib/core/nested/service.dart (too deep)
      expect(
        rule.canImport(
          'lib/core/nested/service.dart',
          Import(uri: 'lib/data/repo.dart'),
        ),
        isTrue,
      );
    });

    test('target pattern with double wildcard matches multiple levels', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/**/service.dart'],
        disallow: ['lib/data/**'],
      );

      // Matches lib/core/service.dart
      expect(
        rule.canImport(
          'lib/core/service.dart',
          Import(uri: 'lib/data/repo.dart'),
        ),
        isFalse,
      );

      // Matches lib/core/nested/service.dart
      expect(
        rule.canImport(
          'lib/core/nested/service.dart',
          Import(uri: 'lib/data/repo.dart'),
        ),
        isFalse,
      );
    });

    test('target pattern "**" matches any files', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['**'],
        disallow: ['lib/data/**'],
      );

      // Matches files in lib/
      expect(
        rule.canImport('lib/app.dart', Import(uri: 'lib/data/repo.dart')),
        isFalse,
      );

      // Matches files in test/
      expect(
        rule.canImport('test/helper.dart', Import(uri: 'lib/data/repo.dart')),
        isFalse,
      );

      // Matches files in example/
      expect(
        rule.canImport('example/demo.dart', Import(uri: 'lib/data/repo.dart')),
        isFalse,
      );

      // Matches nested files
      expect(
        rule.canImport(
          'lib/features/auth/login.dart',
          Import(uri: 'lib/data/repo.dart'),
        ),
        isFalse,
      );

      // Matches root level files
      expect(
        rule.canImport('main.dart', Import(uri: 'lib/data/repo.dart')),
        isFalse,
      );

      // Matches package imports
      expect(
        rule.canImport(
          'package:my_app/core.dart',
          Import(uri: 'lib/data/repo.dart'),
        ),
        isFalse,
      );
    });
  });

  group('excludeTarget behavior', () {
    test('rule does not apply when excludeTarget matches', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/**'],
        excludeTarget: ['lib/core/**'],
        disallow: ['package:flutter/**'],
      );

      // Rule applies to lib/features
      expect(
        rule.canImport(
          'lib/features/auth.dart',
          Import(uri: 'package:flutter/material.dart'),
        ),
        isFalse,
      );

      // Rule does not apply to lib/core (excluded)
      expect(
        rule.canImport(
          'lib/core/entity.dart',
          Import(uri: 'package:flutter/material.dart'),
        ),
        isTrue,
      );
    });

    test('excludeTarget with multiple patterns', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/**'],
        excludeTarget: ['lib/core/**', 'lib/shared/**'],
        disallow: ['package:flutter/**'],
      );

      expect(
        rule.canImport(
          'lib/features/auth.dart',
          Import(uri: 'package:flutter/material.dart'),
        ),
        isFalse,
      );
      expect(
        rule.canImport(
          'lib/core/entity.dart',
          Import(uri: 'package:flutter/material.dart'),
        ),
        isTrue,
      );
      expect(
        rule.canImport(
          'lib/shared/utils.dart',
          Import(uri: 'package:flutter/material.dart'),
        ),
        isTrue,
      );
    });
  });

  group('Disallow matching', () {
    test('import allowed when importee does not match disallow', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/**'],
        disallow: ['package:flutter/**'],
      );

      expect(
        rule.canImport('lib/app.dart', Import(uri: 'package:http/http.dart')),
        isTrue,
      );
    });

    test('import denied when importee matches disallow', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/**'],
        disallow: ['package:flutter/**'],
      );

      expect(
        rule.canImport(
          'lib/app.dart',
          Import(uri: 'package:flutter/material.dart'),
        ),
        isFalse,
      );
    });

    test('disallow with exact path match', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/**'],
        disallow: ['lib/data/db.dart'],
      );

      expect(
        rule.canImport('lib/app.dart', Import(uri: 'lib/data/db.dart')),
        isFalse,
      );
      expect(
        rule.canImport('lib/app.dart', Import(uri: 'lib/data/repo.dart')),
        isTrue,
      );
    });
  });

  group('excludeDisallow behavior', () {
    test('import allowed when importee matches excludeDisallow', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/**'],
        disallow: ['lib/data/**'],
        excludeDisallow: ['lib/data/models/**'],
      );

      // Matches disallow but also matches excludeDisallow
      expect(
        rule.canImport(
          'lib/app.dart',
          Import(uri: 'lib/data/models/user.dart'),
        ),
        isTrue,
      );

      // Matches disallow but not excludeDisallow
      expect(
        rule.canImport('lib/app.dart', Import(uri: 'lib/data/repo.dart')),
        isFalse,
      );
    });

    test('excludeDisallow with multiple patterns', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/**'],
        disallow: ['lib/internal/**'],
        excludeDisallow: ['lib/internal/models/**', 'lib/internal/utils/**'],
      );

      expect(
        rule.canImport(
          'lib/app.dart',
          Import(uri: 'lib/internal/models/user.dart'),
        ),
        isTrue,
      );
      expect(
        rule.canImport(
          'lib/app.dart',
          Import(uri: 'lib/internal/utils/helper.dart'),
        ),
        isTrue,
      );
      expect(
        rule.canImport(
          'lib/app.dart',
          Import(uri: 'lib/internal/private.dart'),
        ),
        isFalse,
      );
    });
  });

  group('\$DIR substitution', () {
    test('substitutes DIR in excludeDisallow patterns', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['**'],
        disallow: ['**'],
        excludeDisallow: [r'$DIR/**'],
      );

      // lib/features/auth.dart has DIR=lib/features
      // Can import lib/features/user.dart (matches lib/features/**)
      expect(
        rule.canImport(
          'lib/features/auth.dart',
          Import(uri: 'lib/features/user.dart'),
        ),
        isTrue,
      );

      // Cannot import lib/core/entity.dart (doesn't match lib/features/**)
      expect(
        rule.canImport(
          'lib/features/auth.dart',
          Import(uri: 'lib/core/entity.dart'),
        ),
        isFalse,
      );
    });

    test('DIR is extracted from parent directory of target file', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/features/auth/models/user.dart'],
        disallow: ['**'],
        excludeDisallow: [r'$DIR/**'],
      );

      // DIR should be lib/features/auth/models
      expect(
        rule.canImport(
          'lib/features/auth/models/user.dart',
          Import(uri: 'lib/features/auth/models/dto.dart'),
        ),
        isTrue,
      );
      expect(
        rule.canImport(
          'lib/features/auth/models/user.dart',
          Import(uri: 'lib/features/auth/login.dart'),
        ),
        isFalse,
      );
    });

    test('DIR substitution works with multiple occurrences', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['**'],
        disallow: ['**'],
        excludeDisallow: [r'$DIR/**', r'$DIR.dart'],
      );

      expect(
        rule.canImport(
          'lib/features/auth.dart',
          Import(uri: 'lib/features/user.dart'),
        ),
        isTrue,
      );
      expect(
        rule.canImport(
          'lib/features/auth.dart',
          Import(uri: 'lib/features.dart'),
        ),
        isTrue,
      );
    });

    test('DIR works with package imports', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['package:my_app/**'],
        disallow: ['**'],
        excludeDisallow: [r'$DIR/**'],
      );

      // package:my_app/features/auth.dart has DIR=package:my_app/features
      expect(
        rule.canImport(
          'package:my_app/features/auth.dart',
          Import(uri: 'package:my_app/features/user.dart'),
        ),
        isTrue,
      );
      expect(
        rule.canImport(
          'package:my_app/features/auth.dart',
          Import(uri: 'package:my_app/core/entity.dart'),
        ),
        isFalse,
      );
    });
  });

  group('Glob pattern specifics', () {
    test('* matches any characters except /', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/*.dart'],
        disallow: ['lib/internal/**'],
      );

      // Matches lib/app.dart
      expect(
        rule.canImport(
          'lib/app.dart',
          Import(uri: 'lib/internal/private.dart'),
        ),
        isFalse,
      );

      // Does not match lib/features/auth.dart (has /)
      expect(
        rule.canImport(
          'lib/features/auth.dart',
          Import(uri: 'lib/internal/private.dart'),
        ),
        isTrue,
      );
    });

    test('** matches across directory levels', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/**'],
        disallow: ['test/**'],
      );

      expect(
        rule.canImport('lib/app.dart', Import(uri: 'test/helper.dart')),
        isFalse,
      );
      expect(
        rule.canImport(
          'lib/features/auth.dart',
          Import(uri: 'test/fixtures/user.dart'),
        ),
        isFalse,
      );
    });

    test('exact path matching', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/main.dart'],
        disallow: ['lib/internal.dart'],
      );

      // Exact match on target
      expect(
        rule.canImport('lib/main.dart', Import(uri: 'lib/internal.dart')),
        isFalse,
      );

      // No match on target
      expect(
        rule.canImport('lib/app.dart', Import(uri: 'lib/internal.dart')),
        isTrue,
      );
    });
  });

  group('Empty list edge cases', () {
    test('empty excludeTarget list behaves correctly', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/**'],
        excludeTarget: [], // Empty
        disallow: ['package:flutter/**'],
      );

      expect(
        rule.canImport(
          'lib/app.dart',
          Import(uri: 'package:flutter/material.dart'),
        ),
        isFalse,
      );
    });

    test('empty excludeDisallow list behaves correctly', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/**'],
        disallow: ['lib/data/**'],
        excludeDisallow: [], // Empty
      );

      expect(
        rule.canImport('lib/app.dart', Import(uri: 'lib/data/repo.dart')),
        isFalse,
      );
    });
  });

  group('Rule evaluation order', () {
    test('target must match first', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/features/**'],
        disallow: ['lib/data/**'],
      );

      // Target doesn't match, so rule doesn't apply even though disallow would match
      expect(
        rule.canImport(
          'lib/core/entity.dart',
          Import(uri: 'lib/data/repo.dart'),
        ),
        isTrue,
      );
    });

    test('excludeTarget checked after target', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/**'],
        excludeTarget: ['lib/core/**'],
        disallow: ['lib/data/**'],
      );

      // Target matches, but excludeTarget also matches
      expect(
        rule.canImport(
          'lib/core/entity.dart',
          Import(uri: 'lib/data/repo.dart'),
        ),
        isTrue,
      );
    });

    test('disallow checked after target matching', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/features/**'],
        disallow: ['lib/data/**'],
      );

      // Target matches, importee doesn't match disallow
      expect(
        rule.canImport(
          'lib/features/auth.dart',
          Import(uri: 'lib/core/entity.dart'),
        ),
        isTrue,
      );
    });

    test('excludeDisallow checked last', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/**'],
        disallow: ['lib/data/**'],
        excludeDisallow: ['lib/data/models/**'],
      );

      // Target matches, disallow matches, excludeDisallow matches
      expect(
        rule.canImport(
          'lib/app.dart',
          Import(uri: 'lib/data/models/user.dart'),
        ),
        isTrue,
      );
    });
  });

  group('Multiple patterns in single field', () {
    test('handles multiple target patterns', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/presentation/**', 'lib/ui/**'],
        disallow: ['lib/data/**'],
      );

      expect(
        rule.canImport(
          'lib/presentation/home.dart',
          Import(uri: 'lib/data/repo.dart'),
        ),
        isFalse,
      );
      expect(
        rule.canImport('lib/ui/home.dart', Import(uri: 'lib/data/repo.dart')),
        isFalse,
      );
    });

    test('handles multiple disallow patterns', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/core/**'],
        disallow: ['package:flutter/**', 'lib/ui/**'],
      );

      expect(
        rule.canImport(
          'lib/core/entity.dart',
          Import(uri: 'package:flutter/material.dart'),
        ),
        isFalse,
      );
      expect(
        rule.canImport(
          'lib/core/entity.dart',
          Import(uri: 'lib/ui/widget.dart'),
        ),
        isFalse,
      );
    });
  });

  group('DIR extraction for different file types', () {
    test('extracts directory from nested file path', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/features/auth/src/utils.dart'],
        disallow: ['**/src/**'],
        excludeDisallow: [r'$DIR/**'],
      );

      // We can test this indirectly by checking if $DIR substitution works
      expect(
        rule.canImport(
          'lib/features/auth/src/utils.dart',
          Import(uri: 'lib/features/auth/src/cache.dart'),
        ),
        isTrue, // Should match $DIR/** which is lib/features/auth/src/**
      );
    });

    test('handles package imports', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['package:flutter/widgets/container.dart'],
        disallow: ['**'],
        excludeDisallow: [r'$DIR/**'],
      );

      // $DIR should be package:flutter/widgets
      expect(
        rule.canImport(
          'package:flutter/widgets/container.dart',
          Import(uri: 'package:flutter/widgets/text.dart'),
        ),
        isTrue,
      );
    });
  });
}
