import 'dart:io';

import 'package:test/test.dart';

import 'src/analyzer_output.dart';
import 'src/io_extension.dart';
import 'src/matchers.dart';
import 'src/test_environment.dart';

void main() {
  const sdkVersionConstraint = '^3.10.0';
  late final Directory pluginRoot;
  late final TestEnvironment env;

  setUpAll(() {
    env = TestEnvironment(root: Directory('.e2e'))..setUp();
    pluginRoot = Directory.current;
  });

  tearDownAll(() {
    env.tearDown();
  });

  group('Use case - ', () {
    // We're going to share pubspec.yaml, pubspec.lock, and .dart_tool from the template package
    // across all test packages in this group to avoid running "dart pub get" multiple times.
    late final DartPackage packageTemplate;
    late final Directory testGroupRoot;
    late DartPackage packageUnderTest;

    setUpAll(() {
      testGroupRoot = env.root.childDirectory('package-tests');
      packageTemplate = env.createPackage(
        name: 'test_package',
        root: testGroupRoot.childDirectory('template'),
        sdkVersionConstraint: sdkVersionConstraint,
        dependencies: {'http': '^1.6.0', 'uuid': '^4.5.2'},
      );
      packageTemplate.pubGet();
      assert(packageTemplate.dartTool.existsSync());
      assert(packageTemplate.pubspecLock.existsSync());
    });

    setUp(() {
      packageUnderTest = env.createPackage(
        name: packageTemplate.name,
        root: testGroupRoot.childDirectory('test_package'),
        sdkVersionConstraint: sdkVersionConstraint,
      );

      packageUnderTest.pubspec.deleteSync();
      packageUnderTest.root
          .childSymlink('pubspec.yaml')
          .createSync(packageTemplate.pubspec.absolute.path);
      packageUnderTest.root
          .childSymlink('pubspec.lock')
          .createSync(packageTemplate.pubspecLock.absolute.path);
      packageUnderTest.root
          .childSymlink('.dart_tool')
          .createSync(packageTemplate.dartTool.absolute.path);
      packageUnderTest.root
          .childFile('analysis_options.yaml')
          .writeAsStringSync('''
analyzer:
  errors:
    unused_import: ignore

plugins:
  import_rules:
    path: ${pluginRoot.absolute.path} 
''');
    });

    tearDown(() {
      packageUnderTest.root.deleteSync(recursive: true);
    });

    test('Keep domain layer pure', () {
      const importRulesYaml = '''
rules:
  - target: lib/domain/**
    disallow: "**"
    exclude_disallow:
      - lib/domain/**
      - package:uuid/uuid.dart
      - dart:collection
      - dart:math
    reason: >
      The domain layer should not depend on other layers
      and external packages with a few exceptions.
''';

      const domainDart = '''
// Allowed imports
import 'src/entity.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

// Disallowed imports
import '../repository/user_repository.dart';
import 'package:test_package/repository/product_repository.dart';
import 'package:http/http.dart';
import 'dart:io';
''';

      const repositoryDart = '''
import '../domain/domain.dart';
import 'package:test_package/domain/src/entity.dart';
import 'package:http/http.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import 'dart:io';
''';

      packageUnderTest.root
        ..childFile('import_rules.yaml').writeAsStringSync(importRulesYaml)
        ..createFiles({
          'lib': {
            'domain': {
              'domain.dart': domainDart,
              'src': {'entity.dart': ''},
            },
            'repository': {
              'repository.dart': repositoryDart,
              'user_repository.dart': '',
              'product_repository.dart': '',
            },
          },
        });

      final analyzerOutput = packageUnderTest.analyze();
      expect(
        analyzerOutput,
        containsLintErrors(
          exclusive: true,
          file: 'lib/domain/domain.dart',
          diagnostics: [
            LintDiagnostic(
              line: 7,
              col: 1,
              message:
                  'Import rule violation. The domain layer should not depend on '
                  'other layers and external packages with a few exceptions.',
              code: 'import_rule_violation',
            ),
            LintDiagnostic(
              line: 8,
              col: 1,
              message:
                  'Import rule violation. The domain layer should not depend on '
                  'other layers and external packages with a few exceptions.',
              code: 'import_rule_violation',
            ),
            LintDiagnostic(
              line: 9,
              col: 1,
              message:
                  'Import rule violation. The domain layer should not depend on '
                  'other layers and external packages with a few exceptions.',
              code: 'import_rule_violation',
            ),
            LintDiagnostic(
              line: 10,
              col: 1,
              message:
                  'Import rule violation. The domain layer should not depend on '
                  'other layers and external packages with a few exceptions.',
              code: 'import_rule_violation',
            ),
          ],
        ),
      );

      expect(
        analyzerOutput,
        isNot(containsAnyLintErrors(file: 'lib/repository/repository.dart')),
      );
    });

    test('Downward dependency only', () {
      const importRulesYaml = r'''
rules:
  - target: "**"
    disallow: "**"
    exclude_disallow: "$TARGET_DIR/**"
    reason: Files can only import from same or deeper directory levels.
''';

      const mainDart = '''
import 'features/features.dart';
import 'features/auth/auth.dart';
import 'features/cart/cart.dart';
''';

      const featuresDart = '''
import '../main.dart';
import 'auth/auth.dart';
import 'cart/cart.dart';
''';

      const authDart = '''
import 'auth_utils.dart';
import '../features.dart';
import '../cart/cart.dart';
''';

      const cartDart = '''
import '../auth/auth.dart';
''';

      packageUnderTest.root
        ..childFile('import_rules.yaml').writeAsStringSync(importRulesYaml)
        ..createFiles({
          'lib': {
            'main.dart': mainDart,
            'features': {
              'features.dart': featuresDart,
              'auth': {'auth.dart': authDart, 'auth_utils.dart': ''},
              'cart': {'cart.dart': cartDart},
            },
          },
        });

      final analyzerOutput = packageUnderTest.analyze();
      expect(
        analyzerOutput,
        isNot(containsAnyLintErrors(file: 'lib/main.dart')),
      );
      expect(
        analyzerOutput,
        containsLintErrors(
          exclusive: true,
          file: 'lib/features/features.dart',
          diagnostics: [
            LintDiagnostic(
              line: 1,
              col: 1,
              message:
                  'Import rule violation. Files can only import from same or deeper directory levels.',
              code: 'import_rule_violation',
            ),
          ],
        ),
      );
      expect(
        analyzerOutput,
        containsLintErrors(
          exclusive: true,
          file: 'lib/features/auth/auth.dart',
          diagnostics: [
            LintDiagnostic(
              line: 2,
              col: 1,
              message:
                  'Import rule violation. Files can only import from same or deeper directory levels.',
              code: 'import_rule_violation',
            ),
            LintDiagnostic(
              line: 3,
              col: 1,
              message:
                  'Import rule violation. Files can only import from same or deeper directory levels.',
              code: 'import_rule_violation',
            ),
          ],
        ),
      );
      expect(
        analyzerOutput,
        containsLintErrors(
          exclusive: true,
          file: 'lib/features/cart/cart.dart',
          diagnostics: [
            LintDiagnostic(
              line: 1,
              col: 1,
              message:
                  'Import rule violation. Files can only import from same or deeper directory levels.',
              code: 'import_rule_violation',
            ),
          ],
        ),
      );
    });

    test('Force uni-directional layer dependencies', () {
      const importRulesYaml = r'''
rules:
  - target: lib/domain/**
    disallow: lib/**
    exclude_disallow: lib/domain/**
    reason: Domain layer should not depend on other layers.

  - target: lib/persistence/**
    disallow:
      - lib/application/**
      - lib/presentation/**
    reason: Persistence layer can not depend on application and presentation layers.

  - target: lib/application/**
    disallow: lib/presentation/**
    reason: Application layer can not depend on presentation layer.

  - target: lib/presentation/**
    disallow:
      - lib/persistence/**
      - lib/domain/**
    reason: Presentation layer should depend only on application layer.
''';

      const domainDart = '''
import 'entity.dart';
import 'package:test_package/persistence/repository.dart';
import '../application/use_case.dart';
import '../presentation/view.dart';
''';

      const repositoryDart = '''
import 'database.dart';
import '../domain/domain.dart';
import '../application/use_case.dart';
''';

      const useCaseDart = '''
import '../domain/entity.dart';
import '../persistence/repository.dart';
import '../presentation/view.dart';
''';

      const viewDart = '''
import 'package:test_package/application/use_case.dart';
import 'package:test_package/domain/entity.dart';
import 'package:test_package/persistence/repository.dart';
''';

      packageUnderTest.root
        ..childFile('import_rules.yaml').writeAsStringSync(importRulesYaml)
        ..createFiles({
          'lib': {
            'domain': {'domain.dart': domainDart, 'entity.dart': ''},
            'persistence': {
              'repository.dart': repositoryDart,
              'database.dart': '',
            },
            'application': {'use_case.dart': useCaseDart},
            'presentation': {'view.dart': viewDart},
          },
        });

      final analyzerOutput = packageUnderTest.analyze();

      expect(
        analyzerOutput,
        containsLintErrors(
          file: 'lib/domain/domain.dart',
          exclusive: true,
          diagnostics: [
            LintDiagnostic(
              line: 2,
              col: 1,
              message:
                  'Import rule violation. Domain layer should not depend on other layers.',
              code: 'import_rule_violation',
            ),
            LintDiagnostic(
              line: 3,
              col: 1,
              message:
                  'Import rule violation. Domain layer should not depend on other layers.',
              code: 'import_rule_violation',
            ),
            LintDiagnostic(
              line: 4,
              col: 1,
              message:
                  'Import rule violation. Domain layer should not depend on other layers.',
              code: 'import_rule_violation',
            ),
          ],
        ),
      );

      expect(
        analyzerOutput,
        containsLintErrors(
          exclusive: true,
          file: 'lib/persistence/repository.dart',
          diagnostics: [
            LintDiagnostic(
              line: 3,
              col: 1,
              message:
                  'Import rule violation. Persistence layer can not '
                  'depend on application and presentation layers.',
              code: 'import_rule_violation',
            ),
          ],
        ),
      );

      expect(
        analyzerOutput,
        containsLintErrors(
          exclusive: true,
          file: 'lib/application/use_case.dart',
          diagnostics: [
            LintDiagnostic(
              line: 3,
              col: 1,
              message:
                  'Import rule violation. Application layer can not depend on presentation layer.',
              code: 'import_rule_violation',
            ),
          ],
        ),
      );

      expect(
        analyzerOutput,
        containsLintErrors(
          exclusive: true,
          file: 'lib/presentation/view.dart',
          diagnostics: [
            LintDiagnostic(
              line: 2,
              col: 1,
              message:
                  'Import rule violation. Presentation layer should depend only on application layer.',
              code: 'import_rule_violation',
            ),
            LintDiagnostic(
              line: 3,
              col: 1,
              message:
                  'Import rule violation. Presentation layer should depend only on application layer.',
              code: 'import_rule_violation',
            ),
          ],
        ),
      );
    });

    test('Feature module isolation', () {
      const importRulesYaml = r'''
rules:
  - target: lib/features/**
    disallow: lib/features/**
    exclude_disallow:
      - $TARGET_DIR/**
      - lib/features/core/**
    reason: Features should be isolated from each other except the core module.
''';

      const modelsDart = '''
import '../auth/auth_service.dart';
import 'src/utils.dart';
''';

      const authServiceDart = '''
import 'package:test_package/features/core/models.dart';
import 'package:test_package/features/core/src/utils.dart';
import 'package:test_package/features/profile/profile_service.dart';
''';

      const profileDart = '''
import '../core/models.dart';
import '../core/src/utils.dart';
import '../auth/auth_service.dart';
''';

      packageUnderTest.root
        ..childFile('import_rules.yaml').writeAsStringSync(importRulesYaml)
        ..createFiles({
          'lib': {
            'features': {
              'core': {
                'models.dart': modelsDart,
                'src': {'utils.dart': ''},
              },
              'auth': {'auth_service.dart': authServiceDart},
              'profile': {'profile_service.dart': profileDart},
            },
          },
        });

      final analyzerOutput = packageUnderTest.analyze();

      expect(
        analyzerOutput,
        containsLintErrors(
          exclusive: true,
          file: 'lib/features/core/models.dart',
          diagnostics: [
            LintDiagnostic(
              line: 1,
              col: 1,
              message:
                  'Import rule violation. Features should be isolated '
                  'from each other except the core module.',
              code: 'import_rule_violation',
            ),
          ],
        ),
      );

      expect(
        analyzerOutput,
        containsLintErrors(
          exclusive: true,
          file: 'lib/features/auth/auth_service.dart',
          diagnostics: [
            LintDiagnostic(
              line: 3,
              col: 1,
              message:
                  'Import rule violation. Features should be isolated '
                  'from each other except the core module.',
              code: 'import_rule_violation',
            ),
          ],
        ),
      );

      expect(
        analyzerOutput,
        containsLintErrors(
          exclusive: true,
          file: 'lib/features/profile/profile_service.dart',
          diagnostics: [
            LintDiagnostic(
              line: 3,
              col: 1,
              message:
                  'Import rule violation. Features should be isolated '
                  'from each other except the core module.',
              code: 'import_rule_violation',
            ),
          ],
        ),
      );
    });

    test('Third package wrapper enforcement', () {
      const importRulesYaml = r'''
rules:
  - target: lib/**
    exclude_target: lib/core/http_wrapper.dart
    disallow: package:http/**
    reason: Use lib/core/http_wrapper.dart instead of directly importing the "http" package.
''';

      const httpWrapperDart = '''
import 'package:http/http.dart' as http;

export 'package:http/http.dart' show Response;

Future<http.Response> get(Uri url, {Map<String, String>? headers}) {
  // Perform some logging or other operations here.
  // Then, forward the request to the actual http package.
  return http.get(url, headers: headers);
}
''';

      const userApiDart = '''
import 'package:test_package/core/http_wrapper.dart' as http;
''';

      const productApiDart = '''
import 'package:http/http.dart' as http;
''';

      packageUnderTest.root
        ..childFile('import_rules.yaml').writeAsStringSync(importRulesYaml)
        ..createFiles({
          'lib': {
            'core': {'http_wrapper.dart': httpWrapperDart},
            'api': {
              'user_api.dart': userApiDart,
              'product_api.dart': productApiDart,
            },
          },
        });

      final analyzerOutput = packageUnderTest.analyze();

      expect(
        analyzerOutput,
        isNot(containsAnyLintErrors(file: 'lib/core/http_wrapper.dart')),
      );

      expect(
        analyzerOutput,
        isNot(containsAnyLintErrors(file: 'lib/api/user_api.dart')),
      );

      expect(
        analyzerOutput,
        containsLintErrors(
          exclusive: true,
          file: 'lib/api/product_api.dart',
          diagnostics: [
            LintDiagnostic(
              line: 1,
              col: 1,
              message:
                  'Import rule violation. Use lib/core/http_wrapper.dart '
                  'instead of directly importing the "http" package.',
              code: 'import_rule_violation',
            ),
          ],
        ),
      );
    });

    test('Legacy code deprecation', () {
      const importRulesYaml = '''
rules:
  - target: lib/features/**
    exclude_target:
      - lib/features/legacy/**
      - lib/features/profile/**
    disallow: lib/features/legacy/**
    reason: Newly added features should not depend on legacy code.
''';

      const legacyAuthDart = '''
import 'token_utils.dart';
''';

      const profileDart = '''
import 'package:test_package/features/legacy/auth/auth.dart';
''';

      const feedDart = '''
import 'package:test_package/features/legacy/auth/auth.dart';
import 'package:test_package/features/auth/auth.dart';
''';

      packageUnderTest.root
        ..childFile('import_rules.yaml').writeAsStringSync(importRulesYaml)
        ..createFiles({
          'lib': {
            'features': {
              'legacy': {
                'auth': {'auth.dart': legacyAuthDart, 'token_utils.dart': ''},
              },
              'auth': {'auth.dart': ''},
              'profile': {'profile.dart': profileDart},
              'feed': {'feed.dart': feedDart},
            },
          },
        });

      final analyzerOutput = packageUnderTest.analyze();

      expect(
        analyzerOutput,
        isNot(
          containsAnyLintErrors(
            file: 'lib/features/legacy/auth/legacy_auth.dart',
          ),
        ),
        reason: 'Legacy code can depend on other legacy code.',
      );

      expect(
        analyzerOutput,
        isNot(containsAnyLintErrors(file: 'lib/features/profile/profile.dart')),
        reason:
            'Profile module is exceptionally allowed to depend on legacy code.',
      );

      expect(
        analyzerOutput,
        containsLintErrors(
          exclusive: true,
          file: 'lib/features/feed/feed.dart',
          diagnostics: [
            LintDiagnostic(
              line: 1,
              col: 1,
              message:
                  'Import rule violation. Newly added features should not depend on legacy code.',
              code: 'import_rule_violation',
            ),
          ],
        ),
        reason: 'Feed module should not depend on legacy code.',
      );
    });

    test('Forbid IO operations in unit testing', () {
      const importRulesYaml = '''
rules:
  - target: test/unit/**
    disallow: dart:io
    reason: Unit tests should not perform IO operations.
''';

      const mainDart = '''
import 'dart:io';
''';

      const domainTestDart = '''
import 'dart:io';
''';

      packageUnderTest.root
        ..childFile('import_rules.yaml').writeAsStringSync(importRulesYaml)
        ..createFiles({
          'lib': {'main.dart': mainDart},
          'test': {
            'unit': {'domain_test.dart': domainTestDart},
          },
        });

      final analyzerOutput = packageUnderTest.analyze();

      expect(
        analyzerOutput,
        isNot(containsAnyLintErrors(file: 'lib/main.dart')),
      );

      expect(
        analyzerOutput,
        containsLintErrors(
          exclusive: true,
          file: 'test/unit/domain_test.dart',
          diagnostics: [
            LintDiagnostic(
              line: 1,
              col: 1,
              message:
                  'Import rule violation. Unit tests should not perform IO operations.',
              code: 'import_rule_violation',
            ),
          ],
        ),
      );
    });

    test('Prefer aggregate file imports', () {
      const importRulesYaml = '''
rules:
  - target: lib/**
    exclude_target: lib/domain/**
    disallow: lib/domain/**
    exclude_disallow: lib/domain/domain.dart
    reason: Import "domain/domain.dart" instead of directly importing "domain/**/*.dart".
''';

      const domainDart = '''
export 'src/entity.dart';
export 'value.dart' show Value;
''';

      const valueDart = '''
class Value {}
''';

      const mainDart = '''
import 'domain/domain.dart';
import 'domain/value.dart';
import 'domain/src/entity.dart';
''';

      const applicationDart = '''
import 'package:test_package/domain/domain.dart';
import 'package:test_package/domain/value.dart';
import 'package:test_package/domain/src/entity.dart';
''';

      packageUnderTest.root
        ..childFile('import_rules.yaml').writeAsStringSync(importRulesYaml)
        ..createFiles({
          'lib': {
            'main.dart': mainDart,
            'application': {'application.dart': applicationDart},
            'domain': {
              'domain.dart': domainDart,
              'value.dart': valueDart,
              'src': {'entity.dart': ''},
            },
          },
        });

      final analyzerOutput = packageUnderTest.analyze();

      expect(
        analyzerOutput,
        isNot(containsAnyLintErrors(file: 'lib/domain/domain.dart')),
        reason: 'Domain files themselves can import each other.',
      );

      expect(
        analyzerOutput,
        containsLintErrors(
          file: 'lib/main.dart',
          exclusive: true,
          diagnostics: [
            LintDiagnostic(
              line: 2,
              col: 1,
              message:
                  'Import rule violation. Import "domain/domain.dart" instead of '
                  'directly importing "domain/**/*.dart".',
              code: 'import_rule_violation',
            ),
            LintDiagnostic(
              line: 3,
              col: 1,
              message:
                  'Import rule violation. Import "domain/domain.dart" instead of '
                  'directly importing "domain/**/*.dart".',
              code: 'import_rule_violation',
            ),
          ],
        ),
      );

      expect(
        analyzerOutput,
        containsLintErrors(
          exclusive: true,
          file: 'lib/application/application.dart',
          diagnostics: [
            LintDiagnostic(
              line: 2,
              col: 1,
              message:
                  'Import rule violation. Import "domain/domain.dart" '
                  'instead of directly importing "domain/**/*.dart".',
              code: 'import_rule_violation',
            ),
            LintDiagnostic(
              line: 3,
              col: 1,
              message:
                  'Import rule violation. Import "domain/domain.dart" '
                  'instead of directly importing "domain/**/*.dart".',
              code: 'import_rule_violation',
            ),
          ],
        ),
      );
    });

    test('Implementation detail encapsulation', () {
      const importRulesYaml = r'''
rules:
  - target: lib/**
    disallow: lib/**/_*.dart
    exclude_disallow: $TARGET_DIR/_*.dart
    reason: Implementation files should not be imported directly.
''';

      const cacheDart = '''
import '_cache_file_loader.dart';
import '_cache_table.dart';
import '_cache_hash_algorithm.dart';
''';

      const utilsDart = '''
import '../_cache_file_loader.dart';
import '../_cache_table.dart';
import '../_cache_hash_algorithm.dart';
''';

      const mainDart = '''
import 'cache/cache.dart';
import 'cache/_cache_file_loader.dart';
import 'cache/_cache_table.dart';
import 'cache/_cache_hash_algorithm.dart';
''';

      packageUnderTest.root
        ..childFile('import_rules.yaml').writeAsStringSync(importRulesYaml)
        ..createFiles({
          'lib': {
            'main.dart': mainDart,
            'cache': {
              'cache.dart': cacheDart,
              '_cache_file_loader.dart': '',
              '_cache_table.dart': '',
              '_cache_hash_algorithm.dart': '',
              'utils': {'utils.dart': utilsDart},
            },
          },
        });

      final analyzerOutput = packageUnderTest.analyze();

      expect(
        analyzerOutput,
        isNot(containsAnyLintErrors(file: 'lib/cache/cache.dart')),
      );

      expect(
        analyzerOutput,
        containsLintErrors(
          exclusive: true,
          file: 'lib/cache/utils/utils.dart',
          diagnostics: [
            LintDiagnostic(
              line: 1,
              col: 1,
              message:
                  'Import rule violation. Implementation files should not be imported directly.',
              code: 'import_rule_violation',
            ),
            LintDiagnostic(
              line: 2,
              col: 1,
              message:
                  'Import rule violation. Implementation files should not be imported directly.',
              code: 'import_rule_violation',
            ),
            LintDiagnostic(
              line: 3,
              col: 1,
              message:
                  'Import rule violation. Implementation files should not be imported directly.',
              code: 'import_rule_violation',
            ),
          ],
        ),
      );

      expect(
        analyzerOutput,
        containsLintErrors(
          exclusive: true,
          file: 'lib/main.dart',
          diagnostics: [
            LintDiagnostic(
              line: 2,
              col: 1,
              message:
                  'Import rule violation. Implementation files should not be imported directly.',
              code: 'import_rule_violation',
            ),
            LintDiagnostic(
              line: 3,
              col: 1,
              message:
                  'Import rule violation. Implementation files should not be imported directly.',
              code: 'import_rule_violation',
            ),
            LintDiagnostic(
              line: 4,
              col: 1,
              message:
                  'Import rule violation. Implementation files should not be imported directly.',
              code: 'import_rule_violation',
            ),
          ],
        ),
      );
    });
  });
}
