import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import 'src/test_helpers.dart';
import 'src/matchers.dart';

void main() {
  final projectRoot = Directory.current.path;
  final testEnvRoot = p.join(projectRoot, '.e2e');
  final templateDir = p.join(projectRoot, 'e2e', 'test_project');

  setUpAll(() {
    // Clean and create test environment
    final envDir = Directory(testEnvRoot);
    if (envDir.existsSync()) {
      envDir.deleteSync(recursive: true);
    }
    envDir.createSync();
  });

  group('A1: Layer Architecture Enforcement', () {
    late String projectPath;

    setUp(() {
      projectPath = copyTestProject(templateDir, testEnvRoot, 'a1');

      // Generate import_rules.yaml for this specific test suite
      generateImportRules(projectPath, '''
rules:
  - name: Presentation layer isolation
    reason: Presentation layer should not directly import data layer
    target: lib/presentation/**
    disallow: lib/data/**
    exclude_disallow: lib/data/models/**
''');

      runDartPubGet(projectPath);
    });

    test('should disallow presentation → data layer imports', () {
      final result = runDartAnalyze(
        projectPath,
        'lib/presentation/a1_layer_arch.dart',
      );

      expect(
        result,
        containsLintError(
          file: 'lib/presentation/a1_layer_arch.dart',
          line: 4,
          col: 1,
          message: contains(
            'Presentation layer should not directly import data layer',
          ),
        ),
      );
    });

    test('should allow presentation → data/models imports', () {
      final result = runDartAnalyze(
        projectPath,
        'lib/presentation/a1_layer_arch.dart',
      );

      expect(
        result,
        isNot(
          containsLintError(
            file: 'lib/presentation/a1_layer_arch.dart',
            line: 5,
          ),
        ),
      );
    });
  });

  group('A4: src Directory Encapsulation', () {
    late String projectPath;

    setUp(() {
      projectPath = copyTestProject(templateDir, testEnvRoot, 'a4');

      // Generate import_rules.yaml for this specific test suite
      generateImportRules(projectPath, '''
rules:
  - name: src directory encapsulation
    reason: src/ directories are always private to their parent module
    target: "**"
    disallow: "**/src/**"
    exclude_disallow: "\$DIR/**"
''');

      runDartPubGet(projectPath);
    });

    test('should allow importing from same module src/', () {
      final result = runDartAnalyze(
        projectPath,
        'lib/features/auth/a4_src_encapsulation.dart',
      );

      expect(
        result,
        isNot(
          containsLintError(
            file: 'lib/features/auth/a4_src_encapsulation.dart',
            line: 4,
          ),
        ),
      );
    });

    test('should disallow importing from other module src/', () {
      final result = runDartAnalyze(
        projectPath,
        'lib/features/auth/a4_src_encapsulation.dart',
      );

      expect(
        result,
        containsLintError(
          file: 'lib/features/auth/a4_src_encapsulation.dart',
          line: 5,
          col: 1,
          message: contains(
            'src/ directories are always private to their parent module',
          ),
        ),
      );
    });
  });

  // Additional test groups for A2, A3, A5-A11 can be added following the same pattern
}
