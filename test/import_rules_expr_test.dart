import 'package:import_rules/src/import_rule.dart';
import 'package:test/test.dart';

// Helper functions to convert string lists to Target/Disallow lists
List<TargetPattern> _targets(List<String> patterns) =>
    patterns.map((p) => TargetPattern(pattern: p)).toList();

List<DisallowPattern> _disallows(List<String> patterns) =>
    patterns.map((p) => DisallowPattern(pattern: p)).toList();

void main() {
  group('A1: Layer Architecture Enforcement', () {
    final rule = ImportRule(
      reason: 'Presentation layer should not directly import data layer',
      targetPatterns: _targets(['lib/presentation/**']),
      disallowPatterns: _disallows(['lib/data/**']),
      excludeDisallowPatterns: _disallows(['lib/data/models/**']),
    );

    test('allows presentation to import domain models', () {
      expect(
        rule.canImport(
          'lib/presentation/pages/home.dart',
          Import(uri: 'lib/data/models/user.dart'),
        ),
        isTrue,
      );
    });

    test('denies presentation to import data repositories', () {
      expect(
        rule.canImport(
          'lib/presentation/pages/home.dart',
          Import(uri: 'lib/data/repositories/user_repository.dart'),
        ),
        isFalse,
      );
    });

    test('allows non-presentation files to import data layer', () {
      expect(
        rule.canImport(
          'lib/domain/usecases/login.dart',
          Import(uri: 'lib/data/repositories/user_repository.dart'),
        ),
        isTrue,
      );
    });
  });

  group('A2: Core Domain Independence', () {
    final rule = ImportRule(
      reason: 'Core domain must remain framework-agnostic',
      targetPatterns: _targets(['lib/core/**']),
      disallowPatterns: _disallows(['package:flutter/**', 'lib/ui/**']),
    );

    test('denies core to import Flutter packages', () {
      expect(
        rule.canImport(
          'lib/core/entities/user.dart',
          Import(uri: 'package:flutter/material.dart'),
        ),
        isFalse,
      );
    });

    test('denies core to import UI layer', () {
      expect(
        rule.canImport(
          'lib/core/usecases/login.dart',
          Import(uri: 'lib/ui/widgets/button.dart'),
        ),
        isFalse,
      );
    });

    test('allows core to import other core files', () {
      expect(
        rule.canImport(
          'lib/core/usecases/login.dart',
          Import(uri: 'lib/core/entities/user.dart'),
        ),
        isTrue,
      );
    });
  });

  group('A3: Feature Module Boundaries', () {
    final rule = ImportRule(
      reason: 'Features should not cross-import each other',
      targetPatterns: _targets(['lib/features/auth/**']),
      disallowPatterns: _disallows([
        'lib/features/profile/**',
        'lib/features/settings/**',
        'lib/features/cart/**',
      ]),
    );

    test('denies auth to import profile', () {
      expect(
        rule.canImport(
          'lib/features/auth/login.dart',
          Import(uri: 'lib/features/profile/profile_page.dart'),
        ),
        isFalse,
      );
    });

    test('denies auth to import settings', () {
      expect(
        rule.canImport(
          'lib/features/auth/login.dart',
          Import(uri: 'lib/features/settings/settings.dart'),
        ),
        isFalse,
      );
    });

    test('allows auth to import within auth', () {
      expect(
        rule.canImport(
          'lib/features/auth/login.dart',
          Import(uri: 'lib/features/auth/models/user.dart'),
        ),
        isTrue,
      );
    });

    test('allows non-auth features to import profile', () {
      expect(
        rule.canImport(
          'lib/features/settings/settings.dart',
          Import(uri: 'lib/features/profile/profile_page.dart'),
        ),
        isTrue,
      );
    });
  });

  group('A4: src Directory Encapsulation', () {
    final rule = ImportRule(
      reason: 'src/ directories are always private to their parent module',
      targetPatterns: _targets(['**']),
      disallowPatterns: _disallows(['**/src/**']),
      excludeDisallowPatterns: _disallows([r'$TARGET_DIR/**']),
    );

    test('allows same module to import from its own src/', () {
      expect(
        rule.canImport(
          'lib/features/auth/auth.dart',
          Import(uri: 'lib/features/auth/src/utils.dart'),
        ),
        isTrue,
      );
    });

    test('allows imports within same src/', () {
      expect(
        rule.canImport(
          'lib/features/auth/src/cache.dart',
          Import(uri: 'lib/features/auth/src/utils.dart'),
        ),
        isTrue,
      );
    });

    test('allows imports within same src/ at different levels', () {
      expect(
        rule.canImport(
          'lib/core/models/src/entity.dart',
          Import(uri: 'lib/core/models/src/value.dart'),
        ),
        isTrue,
      );
    });

    test('denies cross-module src/ imports', () {
      expect(
        rule.canImport(
          'lib/infrastructure/db.dart',
          Import(uri: 'lib/domain/src/entity.dart'),
        ),
        isFalse,
      );
    });

    test('denies cross-module src/ imports between src/ directories', () {
      expect(
        rule.canImport(
          'lib/features/auth/src/cache.dart',
          Import(uri: 'lib/features/profile/src/utils.dart'),
        ),
        isFalse,
      );
    });
  });

  group('A5: Test Isolation', () {
    final rule = ImportRule(
      reason: 'Unit tests cannot import integration test utilities',
      targetPatterns: _targets(['test/unit/**']),
      disallowPatterns: _disallows(['**']),
      excludeDisallowPatterns: _disallows([
        'test/unit/**',
        'lib/**',
        'package:test/**',
        'package:mockito/**',
      ]),
    );

    test('allows unit tests to import lib/', () {
      expect(
        rule.canImport(
          'test/unit/user_test.dart',
          Import(uri: 'lib/models/user.dart'),
        ),
        isTrue,
      );
    });

    test('allows unit tests to import test package', () {
      expect(
        rule.canImport(
          'test/unit/user_test.dart',
          Import(uri: 'package:test/test.dart'),
        ),
        isTrue,
      );
    });

    test('denies unit tests to import integration tests', () {
      expect(
        rule.canImport(
          'test/unit/user_test.dart',
          Import(uri: 'test/integration/helpers.dart'),
        ),
        isFalse,
      );
    });

    test('allows unit tests to import other unit tests', () {
      expect(
        rule.canImport(
          'test/unit/user_test.dart',
          Import(uri: 'test/unit/fixtures.dart'),
        ),
        isTrue,
      );
    });
  });

  group('A6: Platform Code Isolation', () {
    final rule = ImportRule(
      reason: 'Platform implementations should not cross-import',
      targetPatterns: _targets(['lib/platform/**']),
      disallowPatterns: _disallows(['lib/platform/**']),
      excludeDisallowPatterns: _disallows([
        r'$TARGET_DIR/**',
        'lib/platform/common/**',
      ]),
    );

    test('allows android to import within android', () {
      expect(
        rule.canImport(
          'lib/platform/android/camera.dart',
          Import(uri: 'lib/platform/android/sensor.dart'),
        ),
        isTrue,
      );
    });

    test('denies ios to import android', () {
      expect(
        rule.canImport(
          'lib/platform/ios/camera.dart',
          Import(uri: 'lib/platform/android/camera.dart'),
        ),
        isFalse,
      );
    });

    test('allows web to import common', () {
      expect(
        rule.canImport(
          'lib/platform/web/storage.dart',
          Import(uri: 'lib/platform/common/interface.dart'),
        ),
        isTrue,
      );
    });

    test('allows android to import common', () {
      expect(
        rule.canImport(
          'lib/platform/android/storage.dart',
          Import(uri: 'lib/platform/common/interface.dart'),
        ),
        isTrue,
      );
    });
  });

  group('A7: Barrel File Pattern', () {
    final rule = ImportRule(
      reason: 'Internal files should be accessed via barrel exports',
      targetPatterns: _targets(['**']),
      excludeTargetPatterns: _targets(['lib/features/**']),
      disallowPatterns: _disallows(['lib/features/*/internal/**']),
    );

    test('denies external modules to import internal files', () {
      expect(
        rule.canImport(
          'lib/app.dart',
          Import(uri: 'lib/features/auth/internal/cache.dart'),
        ),
        isFalse,
      );
    });

    test('allows feature modules to import their own internal files', () {
      // Rule doesn't apply to lib/features/** due to excludeTarget
      expect(
        rule.canImport(
          'lib/features/auth/auth.dart',
          Import(uri: 'lib/features/auth/internal/cache.dart'),
        ),
        isTrue,
      );
    });
  });

  group('A8: Deprecated Code Migration', () {
    final rule = ImportRule(
      reason:
          'Legacy modules are deprecated and should not be used in new code',
      targetPatterns: _targets(['lib/features/**']),
      excludeTargetPatterns: _targets(['lib/features/legacy/**']),
      disallowPatterns: _disallows(['lib/features/legacy/**']),
    );

    test('denies new features to import legacy', () {
      expect(
        rule.canImport(
          'lib/features/auth/login.dart',
          Import(uri: 'lib/features/legacy/old_auth.dart'),
        ),
        isFalse,
      );
    });

    test('allows legacy to import legacy', () {
      // Rule doesn't apply to lib/features/legacy/** due to excludeTarget
      expect(
        rule.canImport(
          'lib/features/legacy/old_auth.dart',
          Import(uri: 'lib/features/legacy/utils.dart'),
        ),
        isTrue,
      );
    });
  });

  group('A9: Third-party Package Restriction', () {
    final rule = ImportRule(
      reason: 'Direct firebase_analytics usage is forbidden, use our wrapper',
      targetPatterns: _targets(['lib/**']),
      excludeTargetPatterns: _targets(['lib/core/analytics/**']),
      disallowPatterns: _disallows(['package:firebase_analytics/**']),
    );

    test('denies direct firebase_analytics import', () {
      expect(
        rule.canImport(
          'lib/features/home/home.dart',
          Import(uri: 'package:firebase_analytics/firebase_analytics.dart'),
        ),
        isFalse,
      );
    });

    test('allows analytics wrapper to import firebase_analytics', () {
      // Rule doesn't apply to lib/core/analytics/** due to excludeTarget
      expect(
        rule.canImport(
          'lib/core/analytics/analytics_service.dart',
          Import(uri: 'package:firebase_analytics/firebase_analytics.dart'),
        ),
        isTrue,
      );
    });
  });

  group('A10: Generated Code Protection', () {
    final rule = ImportRule(
      reason: 'Generated code should not import non-generated code',
      targetPatterns: _targets(['lib/**.g.dart', 'lib/**.freezed.dart']),
      disallowPatterns: _disallows(['lib/**']),
      excludeDisallowPatterns: _disallows([
        'lib/**.g.dart',
        'lib/**.freezed.dart',
        'package:**',
      ]),
    );

    test('allows generated code to import packages', () {
      expect(
        rule.canImport(
          'lib/models/user.g.dart',
          Import(uri: 'package:json_annotation/json_annotation.dart'),
        ),
        isTrue,
      );
    });

    test('allows generated code to import other generated code', () {
      expect(
        rule.canImport(
          'lib/models/user.g.dart',
          Import(uri: 'lib/models/address.g.dart'),
        ),
        isTrue,
      );
    });

    test('denies generated code to import non-generated code', () {
      expect(
        rule.canImport(
          'lib/models/user.g.dart',
          Import(uri: 'lib/utils/helpers.dart'),
        ),
        isFalse,
      );
    });
  });

  group('A11: Hierarchical Import Restriction', () {
    final rule = ImportRule(
      reason: 'Files can only import from same or deeper directory levels',
      targetPatterns: _targets(['lib/**']),
      disallowPatterns: _disallows(['**']),
      excludeDisallowPatterns: _disallows([r'$TARGET_DIR/**']),
    );

    test('allows downward imports (same directory, deeper level)', () {
      expect(
        rule.canImport(
          'lib/features/auth/auth.dart',
          Import(uri: 'lib/features/auth/models/user.dart'),
        ),
        isTrue,
      );
    });

    test('allows imports within same directory', () {
      expect(
        rule.canImport(
          'lib/features/auth/auth.dart',
          Import(uri: 'lib/features/auth/login.dart'),
        ),
        isTrue,
      );
    });

    test('denies upward imports (to parent)', () {
      expect(
        rule.canImport(
          'lib/features/auth/auth.dart',
          Import(uri: 'lib/main.dart'),
        ),
        isFalse,
      );
    });

    test('denies sibling module imports', () {
      expect(
        rule.canImport(
          'lib/features/auth/auth.dart',
          Import(uri: 'lib/features/settings/settings.dart'),
        ),
        isFalse,
      );
    });

    test('allows imports to subdirectories', () {
      expect(
        rule.canImport(
          'lib/features/auth/auth.dart',
          Import(uri: 'lib/features/auth/src/cache.dart'),
        ),
        isTrue,
      );
    });
  });
}
