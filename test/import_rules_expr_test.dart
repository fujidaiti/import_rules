import 'package:import_rules/import_rules.dart';
import 'package:test/test.dart';

void main() {
  group('A1: Layer Architecture Enforcement', () {
    final rule = Rule(
      name: 'Presentation layer isolation',
      reason: 'Presentation layer should not directly import data layer',
      target: ['lib/presentation/**'],
      disallow: ['lib/data/**'],
      excludeDisallow: ['lib/data/models/**'],
    );

    test('allows presentation to import domain models', () {
      expect(
        canImport(
          'lib/presentation/pages/home.dart',
          'lib/data/models/user.dart',
          rule,
        ),
        isTrue,
      );
    });

    test('denies presentation to import data repositories', () {
      expect(
        canImport(
          'lib/presentation/pages/home.dart',
          'lib/data/repositories/user_repository.dart',
          rule,
        ),
        isFalse,
      );
    });

    test('allows non-presentation files to import data layer', () {
      expect(
        canImport(
          'lib/domain/usecases/login.dart',
          'lib/data/repositories/user_repository.dart',
          rule,
        ),
        isTrue,
      );
    });
  });

  group('A2: Core Domain Independence', () {
    final rule = Rule(
      name: 'Core independence',
      reason: 'Core domain must remain framework-agnostic',
      target: ['lib/core/**'],
      disallow: ['package:flutter/**', 'lib/ui/**'],
    );

    test('denies core to import Flutter packages', () {
      expect(
        canImport(
          'lib/core/entities/user.dart',
          'package:flutter/material.dart',
          rule,
        ),
        isFalse,
      );
    });

    test('denies core to import UI layer', () {
      expect(
        canImport(
          'lib/core/usecases/login.dart',
          'lib/ui/widgets/button.dart',
          rule,
        ),
        isFalse,
      );
    });

    test('allows core to import other core files', () {
      expect(
        canImport(
          'lib/core/usecases/login.dart',
          'lib/core/entities/user.dart',
          rule,
        ),
        isTrue,
      );
    });
  });

  group('A3: Feature Module Boundaries', () {
    final rule = Rule(
      name: 'Feature module boundaries',
      reason: 'Features should not cross-import each other',
      target: ['lib/features/auth/**'],
      disallow: [
        'lib/features/profile/**',
        'lib/features/settings/**',
        'lib/features/cart/**',
      ],
    );

    test('denies auth to import profile', () {
      expect(
        canImport(
          'lib/features/auth/login.dart',
          'lib/features/profile/profile_page.dart',
          rule,
        ),
        isFalse,
      );
    });

    test('denies auth to import settings', () {
      expect(
        canImport(
          'lib/features/auth/login.dart',
          'lib/features/settings/settings.dart',
          rule,
        ),
        isFalse,
      );
    });

    test('allows auth to import within auth', () {
      expect(
        canImport(
          'lib/features/auth/login.dart',
          'lib/features/auth/models/user.dart',
          rule,
        ),
        isTrue,
      );
    });

    test('allows non-auth features to import profile', () {
      expect(
        canImport(
          'lib/features/settings/settings.dart',
          'lib/features/profile/profile_page.dart',
          rule,
        ),
        isTrue,
      );
    });
  });

  group('A4: src Directory Encapsulation', () {
    final rule = Rule(
      name: 'src directory encapsulation',
      reason: 'src/ directories are always private to their parent module',
      target: ['**'],
      disallow: ['**/src/**'],
      excludeDisallow: [r'$DIR/**'],
    );

    test('allows same module to import from its own src/', () {
      expect(
        canImport(
          'lib/features/auth/auth.dart',
          'lib/features/auth/src/utils.dart',
          rule,
        ),
        isTrue,
      );
    });

    test('allows imports within same src/', () {
      expect(
        canImport(
          'lib/features/auth/src/cache.dart',
          'lib/features/auth/src/utils.dart',
          rule,
        ),
        isTrue,
      );
    });

    test('allows imports within same src/ at different levels', () {
      expect(
        canImport(
          'lib/core/models/src/entity.dart',
          'lib/core/models/src/value.dart',
          rule,
        ),
        isTrue,
      );
    });

    test('denies cross-module src/ imports', () {
      expect(
        canImport(
          'lib/infrastructure/db.dart',
          'lib/domain/src/entity.dart',
          rule,
        ),
        isFalse,
      );
    });

    test('denies cross-module src/ imports between src/ directories', () {
      expect(
        canImport(
          'lib/features/auth/src/cache.dart',
          'lib/features/profile/src/utils.dart',
          rule,
        ),
        isFalse,
      );
    });
  });

  group('A5: Test Isolation', () {
    final rule = Rule(
      name: 'Test isolation',
      reason: 'Unit tests cannot import integration test utilities',
      target: ['test/unit/**'],
      disallow: ['**'],
      excludeDisallow: [
        'test/unit/**',
        'lib/**',
        'package:test/**',
        'package:mockito/**',
      ],
    );

    test('allows unit tests to import lib/', () {
      expect(
        canImport('test/unit/user_test.dart', 'lib/models/user.dart', rule),
        isTrue,
      );
    });

    test('allows unit tests to import test package', () {
      expect(
        canImport('test/unit/user_test.dart', 'package:test/test.dart', rule),
        isTrue,
      );
    });

    test('denies unit tests to import integration tests', () {
      expect(
        canImport(
          'test/unit/user_test.dart',
          'test/integration/helpers.dart',
          rule,
        ),
        isFalse,
      );
    });

    test('allows unit tests to import other unit tests', () {
      expect(
        canImport('test/unit/user_test.dart', 'test/unit/fixtures.dart', rule),
        isTrue,
      );
    });
  });

  group('A6: Platform Code Isolation', () {
    final rule = Rule(
      name: 'Platform code isolation',
      reason: 'Platform implementations should not cross-import',
      target: ['lib/platform/**'],
      disallow: ['lib/platform/**'],
      excludeDisallow: [r'$DIR/**', 'lib/platform/common/**'],
    );

    test('allows android to import within android', () {
      expect(
        canImport(
          'lib/platform/android/camera.dart',
          'lib/platform/android/sensor.dart',
          rule,
        ),
        isTrue,
      );
    });

    test('denies ios to import android', () {
      expect(
        canImport(
          'lib/platform/ios/camera.dart',
          'lib/platform/android/camera.dart',
          rule,
        ),
        isFalse,
      );
    });

    test('allows web to import common', () {
      expect(
        canImport(
          'lib/platform/web/storage.dart',
          'lib/platform/common/interface.dart',
          rule,
        ),
        isTrue,
      );
    });

    test('allows android to import common', () {
      expect(
        canImport(
          'lib/platform/android/storage.dart',
          'lib/platform/common/interface.dart',
          rule,
        ),
        isTrue,
      );
    });
  });

  group('A7: Barrel File Pattern', () {
    final rule = Rule(
      name: 'Use barrel files',
      reason: 'Internal files should be accessed via barrel exports',
      target: ['**'],
      excludeTarget: ['lib/features/**'],
      disallow: ['lib/features/*/internal/**'],
    );

    test('denies external modules to import internal files', () {
      expect(
        canImport(
          'lib/app.dart',
          'lib/features/auth/internal/cache.dart',
          rule,
        ),
        isFalse,
      );
    });

    test('allows feature modules to import their own internal files', () {
      // Rule doesn't apply to lib/features/** due to excludeTarget
      expect(
        canImport(
          'lib/features/auth/auth.dart',
          'lib/features/auth/internal/cache.dart',
          rule,
        ),
        isTrue,
      );
    });
  });

  group('A8: Deprecated Code Migration', () {
    final rule = Rule(
      name: 'Avoid legacy code',
      reason:
          'Legacy modules are deprecated and should not be used in new code',
      target: ['lib/features/**'],
      excludeTarget: ['lib/features/legacy/**'],
      disallow: ['lib/features/legacy/**'],
    );

    test('denies new features to import legacy', () {
      expect(
        canImport(
          'lib/features/auth/login.dart',
          'lib/features/legacy/old_auth.dart',
          rule,
        ),
        isFalse,
      );
    });

    test('allows legacy to import legacy', () {
      // Rule doesn't apply to lib/features/legacy/** due to excludeTarget
      expect(
        canImport(
          'lib/features/legacy/old_auth.dart',
          'lib/features/legacy/utils.dart',
          rule,
        ),
        isTrue,
      );
    });
  });

  group('A9: Third-party Package Restriction', () {
    final rule = Rule(
      name: 'Use analytics wrapper',
      reason: 'Direct firebase_analytics usage is forbidden, use our wrapper',
      target: ['lib/**'],
      excludeTarget: ['lib/core/analytics/**'],
      disallow: ['package:firebase_analytics/**'],
    );

    test('denies direct firebase_analytics import', () {
      expect(
        canImport(
          'lib/features/home/home.dart',
          'package:firebase_analytics/firebase_analytics.dart',
          rule,
        ),
        isFalse,
      );
    });

    test('allows analytics wrapper to import firebase_analytics', () {
      // Rule doesn't apply to lib/core/analytics/** due to excludeTarget
      expect(
        canImport(
          'lib/core/analytics/analytics_service.dart',
          'package:firebase_analytics/firebase_analytics.dart',
          rule,
        ),
        isTrue,
      );
    });
  });

  group('A10: Generated Code Protection', () {
    final rule = Rule(
      name: 'Generated code isolation',
      reason: 'Generated code should not import non-generated code',
      target: ['lib/**.g.dart', 'lib/**.freezed.dart'],
      disallow: ['lib/**'],
      excludeDisallow: ['lib/**.g.dart', 'lib/**.freezed.dart', 'package:**'],
    );

    test('allows generated code to import packages', () {
      expect(
        canImport(
          'lib/models/user.g.dart',
          'package:json_annotation/json_annotation.dart',
          rule,
        ),
        isTrue,
      );
    });

    test('allows generated code to import other generated code', () {
      expect(
        canImport('lib/models/user.g.dart', 'lib/models/address.g.dart', rule),
        isTrue,
      );
    });

    test('denies generated code to import non-generated code', () {
      expect(
        canImport('lib/models/user.g.dart', 'lib/utils/helpers.dart', rule),
        isFalse,
      );
    });
  });

  group('A11: Hierarchical Import Restriction', () {
    final rule = Rule(
      name: 'Downward dependency only',
      reason: 'Files can only import from same or deeper directory levels',
      target: ['lib/**'],
      disallow: ['**'],
      excludeDisallow: [r'$DIR/**'],
    );

    test('allows downward imports (same directory, deeper level)', () {
      expect(
        canImport(
          'lib/features/auth/auth.dart',
          'lib/features/auth/models/user.dart',
          rule,
        ),
        isTrue,
      );
    });

    test('allows imports within same directory', () {
      expect(
        canImport(
          'lib/features/auth/auth.dart',
          'lib/features/auth/login.dart',
          rule,
        ),
        isTrue,
      );
    });

    test('denies upward imports (to parent)', () {
      expect(
        canImport('lib/features/auth/auth.dart', 'lib/main.dart', rule),
        isFalse,
      );
    });

    test('denies sibling module imports', () {
      expect(
        canImport(
          'lib/features/auth/auth.dart',
          'lib/features/settings/settings.dart',
          rule,
        ),
        isFalse,
      );
    });

    test('allows imports to subdirectories', () {
      expect(
        canImport(
          'lib/features/auth/auth.dart',
          'lib/features/auth/src/cache.dart',
          rule,
        ),
        isTrue,
      );
    });
  });
}
