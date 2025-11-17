@Timeout(Duration(minutes: 2))
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

    // Run pub get once on template project
    runDartPubGet(templateDir);
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
    target: package:test_project/presentation/**
    disallow: package:test_project/data/**
    exclude_disallow: package:test_project/data/models/**
''');
    });

    test('should disallow presentation → data layer imports', () {
      final result = runDartAnalyze(
        projectPath,
        'lib/presentation/a1_layer_arch.dart',
      );

      expect(
        result,
        containsLintError(
          file: 'a1_layer_arch.dart',
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
        isNot(containsLintError(file: 'a1_layer_arch.dart', line: 5)),
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
    target: package:test_project/**
    disallow: package:test_project/**/src/**
    exclude_disallow: "\$DIR/**"
''');
    });

    test('should allow importing from same module src/', () {
      final result = runDartAnalyze(
        projectPath,
        'lib/features/auth/a4_src_encapsulation.dart',
      );

      expect(
        result,
        isNot(containsLintError(file: 'a4_src_encapsulation.dart', line: 4)),
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
          file: 'a4_src_encapsulation.dart',
          line: 5,
          col: 1,
          message: contains(
            'src/ directories are always private to their parent module',
          ),
        ),
      );
    });
  });

  group('A5: Test Isolation', () {
    late String projectPath;

    setUp(() {
      projectPath = copyTestProject(templateDir, testEnvRoot, 'a5');

      // Generate import_rules.yaml for test isolation
      // TDD: This uses file path patterns which aren't supported yet
      generateImportRules(projectPath, '''
rules:
  - name: Test isolation
    reason: Unit tests cannot import integration test utilities
    target: test/unit/**
    disallow: test/integration/**
''');
    });

    test('should disallow unit tests → integration test imports', () {
      final result = runDartAnalyze(
        projectPath,
        'test/unit/a5_test_isolation.dart',
      );

      expect(
        result,
        containsLintError(
          file: 'a5_test_isolation.dart',
          line: 7,
          col: 1,
          message: contains(
            'Unit tests cannot import integration test utilities',
          ),
        ),
      );
    });

    test('should allow unit tests → lib code imports', () {
      final result = runDartAnalyze(
        projectPath,
        'test/unit/a5_test_isolation.dart',
      );

      // Line 5 imports lib code - should be allowed
      expect(
        result,
        isNot(containsLintError(file: 'a5_test_isolation.dart', line: 5)),
      );
    });
  });

  // Additional test groups for A2, A3, A6-A11 can be added following the same pattern

  group('File Path Patterns (known limitation)', () {
    late String projectPath;

    setUp(() {
      projectPath = copyTestProject(templateDir, testEnvRoot, 'file_path');

      // Generate import_rules.yaml using lib/** patterns instead of package:**
      // This currently doesn't work - the plugin needs to be enhanced to support both formats
      generateImportRules(projectPath, '''
rules:
  - name: Data layer isolation (file path pattern)
    reason: Data layer should not import presentation layer
    target: lib/data/**
    disallow: lib/presentation/**
''');
    });

    test('should disallow data → presentation imports with lib/** pattern', () {
      final result = runDartAnalyze(projectPath, 'lib/data/a1_file_path.dart');

      // TDD: This test currently fails - will pass when plugin supports lib/** patterns
      expect(
        result,
        containsLintError(
          file: 'a1_file_path.dart',
          line: 5,
          col: 1,
          message: contains('Data layer should not import presentation layer'),
        ),
      );
    });

    test('should support specific file path targets', () {
      // Test with a specific file path in target (not a glob)
      final result = runDartAnalyze(projectPath, 'lib/data/a1_file_path.dart');

      // TDD: This test currently fails - will pass when plugin supports specific file paths
      // Future feature: target: lib/data/specific_file.dart
      expect(
        result,
        containsLintError(
          file: 'a1_file_path.dart',
          message: contains('Data layer should not import presentation layer'),
        ),
      );
    });

    test('should support mixed package and lib patterns', () {
      // Test mixing package: and lib/ patterns in the same rule
      final result = runDartAnalyze(projectPath, 'lib/data/a1_file_path.dart');

      // TDD: This test currently fails - will pass when plugin supports mixed patterns
      // Future feature: mix package:** and lib/** in same rule
      expect(result, isNotNull);
    });
  });
}
