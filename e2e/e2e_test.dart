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
      const importRulesYaml = r'''
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
                  'Import rule violation. The domain layer should not depend on other layers and external packages with a few exceptions.',
              code: 'import_rule_violation',
            ),
            LintDiagnostic(
              line: 8,
              col: 1,
              message:
                  'Import rule violation. The domain layer should not depend on other layers and external packages with a few exceptions.',
              code: 'import_rule_violation',
            ),
            LintDiagnostic(
              line: 9,
              col: 1,
              message:
                  'Import rule violation. The domain layer should not depend on other layers and external packages with a few exceptions.',
              code: 'import_rule_violation',
            ),
            LintDiagnostic(
              line: 10,
              col: 1,
              message:
                  'Import rule violation. The domain layer should not depend on other layers and external packages with a few exceptions.',
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
    exclude_disallow: "$DIR/**"
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
  });
}
