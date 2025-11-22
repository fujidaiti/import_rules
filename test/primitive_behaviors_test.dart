import 'package:import_rules/src/import_rule.dart';
import 'package:test/test.dart';

// Helper functions to convert string lists to Target/Disallow lists
List<TargetPattern> _targets(List<String> patterns) =>
    patterns.map((p) => TargetPattern(pattern: p)).toList();

List<DisallowPattern> _disallows(List<String> patterns) =>
    patterns.map((p) => DisallowPattern(pattern: p)).toList();

void main() {
  group('Target matching', () {
    test('rule does not apply when target does not match', () {
      final rule = ImportRule(
        reason: 'test',
        targetPatterns: _targets(['lib/features/**']),
        disallowPatterns: _disallows(['lib/data/**']),
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
        targetPatterns: _targets(['lib/features/**']),
        disallowPatterns: _disallows(['lib/data/**']),
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
        targetPatterns: _targets(['lib/*/service.dart']),
        disallowPatterns: _disallows(['lib/data/**']),
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
        targetPatterns: _targets(['lib/**/service.dart']),
        disallowPatterns: _disallows(['lib/data/**']),
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
        targetPatterns: _targets(['**']),
        disallowPatterns: _disallows(['lib/data/**']),
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
        targetPatterns: _targets(['lib/**']),
        excludeTargetPatterns: _targets(['lib/core/**']),
        disallowPatterns: _disallows(['package:flutter/**']),
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
        targetPatterns: _targets(['lib/**']),
        excludeTargetPatterns: _targets(['lib/core/**', 'lib/shared/**']),
        disallowPatterns: _disallows(['package:flutter/**']),
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
        targetPatterns: _targets(['lib/**']),
        disallowPatterns: _disallows(['package:flutter/**']),
      );

      expect(
        rule.canImport('lib/app.dart', Import(uri: 'package:http/http.dart')),
        isTrue,
      );
    });

    test('import denied when importee matches disallow', () {
      final rule = ImportRule(
        reason: 'test',
        targetPatterns: _targets(['lib/**']),
        disallowPatterns: _disallows(['package:flutter/**']),
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
        targetPatterns: _targets(['lib/**']),
        disallowPatterns: _disallows(['lib/data/db.dart']),
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
        targetPatterns: _targets(['lib/**']),
        disallowPatterns: _disallows(['lib/data/**']),
        excludeDisallowPatterns: _disallows(['lib/data/models/**']),
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
        targetPatterns: _targets(['lib/**']),
        disallowPatterns: _disallows(['lib/internal/**']),
        excludeDisallowPatterns: _disallows([
          'lib/internal/models/**',
          'lib/internal/utils/**',
        ]),
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

  group('\$TARGET_DIR substitution', () {
    test('substitutes TARGET_DIR in excludeDisallow patterns', () {
      final rule = ImportRule(
        reason: 'test',
        targetPatterns: _targets(['**']),
        disallowPatterns: _disallows(['**']),
        excludeDisallowPatterns: _disallows([r'$TARGET_DIR/**']),
      );

      // lib/features/auth.dart has TARGET_DIR=lib/features
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

    test('TARGET_DIR is extracted from parent directory of target file', () {
      final rule = ImportRule(
        reason: 'test',
        targetPatterns: _targets(['lib/features/auth/models/user.dart']),
        disallowPatterns: _disallows(['**']),
        excludeDisallowPatterns: _disallows([r'$TARGET_DIR/**']),
      );

      // TARGET_DIR should be lib/features/auth/models
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

    test('TARGET_DIR substitution works with multiple occurrences', () {
      final rule = ImportRule(
        reason: 'test',
        targetPatterns: _targets(['**']),
        disallowPatterns: _disallows(['**']),
        excludeDisallowPatterns: _disallows([
          r'$TARGET_DIR/**',
          r'$TARGET_DIR.dart',
        ]),
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

    test('TARGET_DIR works with package imports', () {
      final rule = ImportRule(
        reason: 'test',
        targetPatterns: _targets(['package:my_app/**']),
        disallowPatterns: _disallows(['**']),
        excludeDisallowPatterns: _disallows([r'$TARGET_DIR/**']),
      );

      // package:my_app/features/auth.dart has TARGET_DIR=package:my_app/features
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
        targetPatterns: _targets(['lib/*.dart']),
        disallowPatterns: _disallows(['lib/internal/**']),
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
        targetPatterns: _targets(['lib/**']),
        disallowPatterns: _disallows(['test/**']),
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
        targetPatterns: _targets(['lib/main.dart']),
        disallowPatterns: _disallows(['lib/internal.dart']),
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
        targetPatterns: _targets(['lib/**']),
        excludeTargetPatterns: _targets([]), // Empty
        disallowPatterns: _disallows(['package:flutter/**']),
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
        targetPatterns: _targets(['lib/**']),
        disallowPatterns: _disallows(['lib/data/**']),
        excludeDisallowPatterns: _disallows([]), // Empty
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
        targetPatterns: _targets(['lib/features/**']),
        disallowPatterns: _disallows(['lib/data/**']),
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
        targetPatterns: _targets(['lib/**']),
        excludeTargetPatterns: _targets(['lib/core/**']),
        disallowPatterns: _disallows(['lib/data/**']),
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
        targetPatterns: _targets(['lib/features/**']),
        disallowPatterns: _disallows(['lib/data/**']),
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
        targetPatterns: _targets(['lib/**']),
        disallowPatterns: _disallows(['lib/data/**']),
        excludeDisallowPatterns: _disallows(['lib/data/models/**']),
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
        targetPatterns: _targets(['lib/presentation/**', 'lib/ui/**']),
        disallowPatterns: _disallows(['lib/data/**']),
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
        targetPatterns: _targets(['lib/core/**']),
        disallowPatterns: _disallows(['package:flutter/**', 'lib/ui/**']),
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

  group('TARGET_DIR extraction for different file types', () {
    test('extracts directory from nested file path', () {
      final rule = ImportRule(
        reason: 'test',
        targetPatterns: _targets(['lib/features/auth/src/utils.dart']),
        disallowPatterns: _disallows(['**/src/**']),
        excludeDisallowPatterns: _disallows([r'$TARGET_DIR/**']),
      );

      // We can test this indirectly by checking if $TARGET_DIR substitution works
      expect(
        rule.canImport(
          'lib/features/auth/src/utils.dart',
          Import(uri: 'lib/features/auth/src/cache.dart'),
        ),
        isTrue, // Should match $TARGET_DIR/** which is lib/features/auth/src/**
      );
    });

    test('handles package imports', () {
      final rule = ImportRule(
        reason: 'test',
        targetPatterns: _targets(['package:flutter/widgets/container.dart']),
        disallowPatterns: _disallows(['**']),
        excludeDisallowPatterns: _disallows([r'$TARGET_DIR/**']),
      );

      // $TARGET_DIR should be package:flutter/widgets
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
