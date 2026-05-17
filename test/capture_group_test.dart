import 'package:import_rules/src/import_rule.dart';
import 'package:test/test.dart';

// Helper functions to convert string lists to Target/Disallow lists
List<TargetPattern> _targets(List<String> patterns) =>
    patterns.map((p) => TargetPattern(pattern: p)).toList();

List<DisallowPattern> _disallows(List<String> patterns) =>
    patterns.map((p) => DisallowPattern(pattern: p)).toList();

void main() {
  group('Single capture group', () {
    // Rule: files under lib/entities/{MODULE}/** cannot import from other
    // modules under lib/entities/, but can import from their own module.
    late ImportRule rule;

    setUp(() {
      rule = ImportRule(
        reason: 'Module isolation',
        targetPatterns: _targets(['lib/entities/{MODULE}/**']),
        disallowPatterns: _disallows(['lib/entities/**']),
        excludeDisallowPatterns: _disallows([r'lib/entities/$MODULE/**']),
      );
    });

    test('same-module import allowed', () {
      // lib/entities/auth/service.dart importing lib/entities/auth/repo.dart
      // should be allowed (same module "auth")
      expect(
        rule.canImport(
          'lib/entities/auth/service.dart',
          Import(uri: 'lib/entities/auth/repo.dart'),
        ),
        isTrue,
      );
    });

    test('cross-module import denied', () {
      // lib/entities/auth/service.dart importing lib/entities/user/repo.dart
      // should be denied (different module)
      expect(
        rule.canImport(
          'lib/entities/auth/service.dart',
          Import(uri: 'lib/entities/user/repo.dart'),
        ),
        isFalse,
      );
    });

    test('non-matching target skips rule', () {
      // lib/core/util.dart does not match target lib/entities/{MODULE}/**
      // so the rule does not apply
      expect(
        rule.canImport(
          'lib/core/util.dart',
          Import(uri: 'lib/entities/user/repo.dart'),
        ),
        isTrue,
      );
    });
  });

  group('Capture group in disallow', () {
    test('capture group substituted in disallow', () {
      // A module cannot import its own internal/ directory
      final rule = ImportRule(
        reason: 'No internal imports',
        targetPatterns: _targets(['lib/features/{FEATURE}/**']),
        disallowPatterns: _disallows([r'lib/features/$FEATURE/internal/**']),
      );

      // Importing own internal → denied
      expect(
        rule.canImport(
          'lib/features/auth/service.dart',
          Import(uri: 'lib/features/auth/internal/helper.dart'),
        ),
        isFalse,
      );

      // Importing own non-internal → allowed (not matched by disallow)
      expect(
        rule.canImport(
          'lib/features/auth/service.dart',
          Import(uri: 'lib/features/auth/models/user.dart'),
        ),
        isTrue,
      );
    });
  });

  group('Multiple capture groups', () {
    // Rule: files under lib/{LAYER}/{MODULE}/** can only import from their
    // own layer+module combination.
    late ImportRule rule;

    setUp(() {
      rule = ImportRule(
        reason: 'Layer-module isolation',
        targetPatterns: _targets(['lib/{LAYER}/{MODULE}/**']),
        disallowPatterns: _disallows(['lib/**']),
        excludeDisallowPatterns: _disallows([r'lib/$LAYER/$MODULE/**']),
      );
    });

    test('both captures substituted - same layer and module allowed', () {
      // lib/domain/auth/service.dart importing lib/domain/auth/repo.dart
      expect(
        rule.canImport(
          'lib/domain/auth/service.dart',
          Import(uri: 'lib/domain/auth/repo.dart'),
        ),
        isTrue,
      );
    });

    test('different layer denied', () {
      // lib/domain/auth/service.dart importing lib/data/auth/repo.dart
      expect(
        rule.canImport(
          'lib/domain/auth/service.dart',
          Import(uri: 'lib/data/auth/repo.dart'),
        ),
        isFalse,
      );
    });

    test('different module denied', () {
      // lib/domain/auth/service.dart importing lib/domain/user/repo.dart
      expect(
        rule.canImport(
          'lib/domain/auth/service.dart',
          Import(uri: 'lib/domain/user/repo.dart'),
        ),
        isFalse,
      );
    });

    test('using only one captured variable', () {
      // Rule that only uses $LAYER in exclude_disallow
      final singleVarRule = ImportRule(
        reason: 'Layer isolation',
        targetPatterns: _targets(['lib/{LAYER}/{MODULE}/**']),
        disallowPatterns: _disallows(['lib/**']),
        excludeDisallowPatterns: _disallows([r'lib/$LAYER/**']),
      );

      // Same layer, different module → allowed (because lib/$LAYER/** matches)
      expect(
        singleVarRule.canImport(
          'lib/domain/auth/service.dart',
          Import(uri: 'lib/domain/user/repo.dart'),
        ),
        isTrue,
      );

      // Different layer → denied
      expect(
        singleVarRule.canImport(
          'lib/domain/auth/service.dart',
          Import(uri: 'lib/data/auth/repo.dart'),
        ),
        isFalse,
      );
    });
  });

  group('Edge cases', () {
    test('captured segment with underscores and numbers', () {
      final rule = ImportRule(
        reason: 'Module isolation',
        targetPatterns: _targets(['lib/entities/{MODULE}/**']),
        disallowPatterns: _disallows(['lib/entities/**']),
        excludeDisallowPatterns: _disallows([r'lib/entities/$MODULE/**']),
      );

      // Module name with underscores and numbers: auth_v2
      expect(
        rule.canImport(
          'lib/entities/auth_v2/service.dart',
          Import(uri: 'lib/entities/auth_v2/repo.dart'),
        ),
        isTrue,
      );

      expect(
        rule.canImport(
          'lib/entities/auth_v2/service.dart',
          Import(uri: 'lib/entities/user/repo.dart'),
        ),
        isFalse,
      );
    });

    test('capture group with deeper nesting after', () {
      final rule = ImportRule(
        reason: 'Service isolation',
        targetPatterns: _targets(['lib/{MODULE}/**/service.dart']),
        disallowPatterns: _disallows(['lib/**']),
        excludeDisallowPatterns: _disallows([r'lib/$MODULE/**']),
      );

      // lib/auth/internal/service.dart → MODULE = auth
      expect(
        rule.canImport(
          'lib/auth/internal/service.dart',
          Import(uri: 'lib/auth/models/user.dart'),
        ),
        isTrue,
      );

      expect(
        rule.canImport(
          'lib/auth/internal/service.dart',
          Import(uri: 'lib/user/models/profile.dart'),
        ),
        isFalse,
      );
    });
  });
}
