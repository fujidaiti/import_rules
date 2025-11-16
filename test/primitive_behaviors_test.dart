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
        canImport('lib/core/entity.dart', 'lib/data/repo.dart', rule),
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
        canImport('lib/features/auth/login.dart', 'lib/data/repo.dart', rule),
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
        canImport('lib/core/service.dart', 'lib/data/repo.dart', rule),
        isFalse,
      );

      // Does not match lib/core/nested/service.dart (too deep)
      expect(
        canImport('lib/core/nested/service.dart', 'lib/data/repo.dart', rule),
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
        canImport('lib/core/service.dart', 'lib/data/repo.dart', rule),
        isFalse,
      );

      // Matches lib/core/nested/service.dart
      expect(
        canImport('lib/core/nested/service.dart', 'lib/data/repo.dart', rule),
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
        canImport(
          'lib/features/auth.dart',
          'package:flutter/material.dart',
          rule,
        ),
        isFalse,
      );

      // Rule does not apply to lib/core (excluded)
      expect(
        canImport(
          'lib/core/entity.dart',
          'package:flutter/material.dart',
          rule,
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
        canImport(
          'lib/features/auth.dart',
          'package:flutter/material.dart',
          rule,
        ),
        isFalse,
      );
      expect(
        canImport(
          'lib/core/entity.dart',
          'package:flutter/material.dart',
          rule,
        ),
        isTrue,
      );
      expect(
        canImport(
          'lib/shared/utils.dart',
          'package:flutter/material.dart',
          rule,
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

      expect(canImport('lib/app.dart', 'package:http/http.dart', rule), isTrue);
    });

    test('import denied when importee matches disallow', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/**'],
        disallow: ['package:flutter/**'],
      );

      expect(
        canImport('lib/app.dart', 'package:flutter/material.dart', rule),
        isFalse,
      );
    });

    test('disallow with exact path match', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/**'],
        disallow: ['lib/data/db.dart'],
      );

      expect(canImport('lib/app.dart', 'lib/data/db.dart', rule), isFalse);
      expect(canImport('lib/app.dart', 'lib/data/repo.dart', rule), isTrue);
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
        canImport('lib/app.dart', 'lib/data/models/user.dart', rule),
        isTrue,
      );

      // Matches disallow but not excludeDisallow
      expect(canImport('lib/app.dart', 'lib/data/repo.dart', rule), isFalse);
    });

    test('excludeDisallow with multiple patterns', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/**'],
        disallow: ['lib/internal/**'],
        excludeDisallow: ['lib/internal/models/**', 'lib/internal/utils/**'],
      );

      expect(
        canImport('lib/app.dart', 'lib/internal/models/user.dart', rule),
        isTrue,
      );
      expect(
        canImport('lib/app.dart', 'lib/internal/utils/helper.dart', rule),
        isTrue,
      );
      expect(
        canImport('lib/app.dart', 'lib/internal/private.dart', rule),
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
        canImport('lib/features/auth.dart', 'lib/features/user.dart', rule),
        isTrue,
      );

      // Cannot import lib/core/entity.dart (doesn't match lib/features/**)
      expect(
        canImport('lib/features/auth.dart', 'lib/core/entity.dart', rule),
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
        canImport(
          'lib/features/auth/models/user.dart',
          'lib/features/auth/models/dto.dart',
          rule,
        ),
        isTrue,
      );
      expect(
        canImport(
          'lib/features/auth/models/user.dart',
          'lib/features/auth/login.dart',
          rule,
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
        canImport('lib/features/auth.dart', 'lib/features/user.dart', rule),
        isTrue,
      );
      expect(
        canImport('lib/features/auth.dart', 'lib/features.dart', rule),
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
        canImport(
          'package:my_app/features/auth.dart',
          'package:my_app/features/user.dart',
          rule,
        ),
        isTrue,
      );
      expect(
        canImport(
          'package:my_app/features/auth.dart',
          'package:my_app/core/entity.dart',
          rule,
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
        canImport('lib/app.dart', 'lib/internal/private.dart', rule),
        isFalse,
      );

      // Does not match lib/features/auth.dart (has /)
      expect(
        canImport('lib/features/auth.dart', 'lib/internal/private.dart', rule),
        isTrue,
      );
    });

    test('** matches across directory levels', () {
      final rule = ImportRule(
        reason: 'test',
        target: ['lib/**'],
        disallow: ['test/**'],
      );

      expect(canImport('lib/app.dart', 'test/helper.dart', rule), isFalse);
      expect(
        canImport('lib/features/auth.dart', 'test/fixtures/user.dart', rule),
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
      expect(canImport('lib/main.dart', 'lib/internal.dart', rule), isFalse);

      // No match on target
      expect(canImport('lib/app.dart', 'lib/internal.dart', rule), isTrue);
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
        canImport('lib/app.dart', 'package:flutter/material.dart', rule),
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

      expect(canImport('lib/app.dart', 'lib/data/repo.dart', rule), isFalse);
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
        canImport('lib/core/entity.dart', 'lib/data/repo.dart', rule),
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
        canImport('lib/core/entity.dart', 'lib/data/repo.dart', rule),
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
        canImport('lib/features/auth.dart', 'lib/core/entity.dart', rule),
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
        canImport('lib/app.dart', 'lib/data/models/user.dart', rule),
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
        canImport('lib/presentation/home.dart', 'lib/data/repo.dart', rule),
        isFalse,
      );
      expect(
        canImport('lib/ui/home.dart', 'lib/data/repo.dart', rule),
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
        canImport(
          'lib/core/entity.dart',
          'package:flutter/material.dart',
          rule,
        ),
        isFalse,
      );
      expect(
        canImport('lib/core/entity.dart', 'lib/ui/widget.dart', rule),
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
        canImport(
          'lib/features/auth/src/utils.dart',
          'lib/features/auth/src/cache.dart',
          rule,
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
        canImport(
          'package:flutter/widgets/container.dart',
          'package:flutter/widgets/text.dart',
          rule,
        ),
        isTrue,
      );
    });
  });
}
