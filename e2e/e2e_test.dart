import 'dart:io';

import 'package:test/test.dart';

import 'src/io_extension.dart';
import 'src/matchers.dart';
import 'test_environment.dart';

void main() {
  const sdkVersionConstraint = '^3.10.0';
  late final Directory pluginRoot;
  late final TestEnvironment env;

  setUpAll(() {
    env = TestEnvironment(root: Directory('.e2e'))..setUp();
    pluginRoot = Directory.current;
  });

  tearDownAll(() {
    // env.tearDown();
  });

  group('No dependency packages tests:', () {
    // We're going to share .dart_tool and pubspec.lock from the template package
    // across all test packages in this group to avoid running "dart pub get" multiple times.
    late final DartPackage templatePackage;
    late final Directory testGroupRoot;

    setUpAll(() {
      testGroupRoot = env.root.childDirectory('no-dependency-packages-tests');
      templatePackage = env.createPackage(
        name: 'template',
        parent: testGroupRoot,
        sdkVersionConstraint: sdkVersionConstraint,
      );
      templatePackage.pubGet();
      assert(templatePackage.dartTool.existsSync());
      assert(templatePackage.pubspecLock.existsSync());
    });

    DartPackage createTestPackage(String name) {
      final package = env.createPackage(
        name: name,
        parent: testGroupRoot,
        sdkVersionConstraint: sdkVersionConstraint,
      );

      package.pubspec.deleteSync();
      package.root
          .childSymlink('pubspec.yaml')
          .createSync(templatePackage.pubspec.absolute.path);
      package.root
          .childSymlink('pubspec.lock')
          .createSync(templatePackage.pubspecLock.absolute.path);
      package.root
          .childSymlink('.dart_tool')
          .createSync(templatePackage.dartTool.absolute.path);
      package.root.childFile('analysis_options.yaml').writeAsStringSync('''
analyzer:
  errors:
    unused_import: ignore

plugins:
  import_rules:
    path: ${pluginRoot.absolute.path} 
''');

      return package;
    }

    test('Downward dependency only', () {
      final package = createTestPackage('downward_dependency_only');
      package.root.childFile('import_rules.yaml').writeAsStringSync(r'''
rules:
  - target: "**"
    disallow: "**"
    exclude_disallow: "$DIR/**"
    reason: Files can only import from same or deeper directory levels.
''');

      const mainDartFile = '''
import 'features/features.dart';
import 'features/auth/auth.dart';
import 'features/cart/cart.dart';
''';

      const featuresDartFile = '''
import '../main.dart';
import 'auth/auth.dart';
import 'cart/cart.dart';
''';

      const authDartFile = '''
import 'auth_utils.dart';
import '../features.dart';
import '../cart/cart.dart';
''';

      const cartDartFile = '''
import '../auth/auth.dart';
''';

      package.root.createFiles({
        'lib': {
          'main.dart': mainDartFile,
          'features': {
            'features.dart': featuresDartFile,
            'auth': {'auth.dart': authDartFile, 'auth_utils.dart': ''},
            'cart': {'cart.dart': cartDartFile},
          },
        },
      });

      package.pubGet();
      final analyzerOutput = package.analyze();
      expect(
        analyzerOutput,
        isNot(containsLintError(file: 'lib/main.dart', line: 1)),
      );
      expect(
        analyzerOutput,
        isNot(containsLintError(file: 'lib/main.dart', line: 2)),
      );
      expect(
        analyzerOutput,
        isNot(containsLintError(file: 'lib/main.dart', line: 3)),
      );
      expect(
        analyzerOutput,
        containsLintError(
          file: 'lib/features/features.dart',
          line: 1,
          message: contains(
            'Files can only import from same or deeper directory levels.',
          ),
        ),
      );
      expect(
        analyzerOutput,
        isNot(containsLintError(file: 'lib/features/features.dart', line: 2)),
      );
      expect(
        analyzerOutput,
        isNot(containsLintError(file: 'lib/features/features.dart', line: 3)),
      );
      expect(
        analyzerOutput,
        isNot(containsLintError(file: 'lib/features/auth/auth.dart', line: 1)),
      );
      expect(
        analyzerOutput,
        containsLintError(
          file: 'lib/features/auth/auth.dart',
          line: 2,
          message: contains(
            'Files can only import from same or deeper directory levels.',
          ),
        ),
      );
      expect(
        analyzerOutput,
        containsLintError(
          file: 'lib/features/auth/auth.dart',
          line: 3,
          message: contains(
            'Files can only import from same or deeper directory levels.',
          ),
        ),
      );
      expect(
        analyzerOutput,
        containsLintError(
          file: 'lib/features/cart/cart.dart',
          line: 1,
          message: contains(
            'Files can only import from same or deeper directory levels.',
          ),
        ),
      );
    });
  });
}
