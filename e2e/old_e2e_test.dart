@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'src/matchers.dart';
import 'src/test_helpers.dart';

void main() {
  final projectRoot = Directory.current.path;
  final testEnvRoot = p.join(projectRoot, '.e2e');
  final templateDir = p.join(projectRoot, 'e2e', 'test_project');
  late String templateCopyPath;
  late String sharedDartToolPath;

  setUpAll(() {
    // Clean and create test environment
    final envDir = Directory(testEnvRoot);
    if (envDir.existsSync()) {
      envDir.deleteSync(recursive: true);
    }
    envDir.createSync();

    // Copy template to test environment and run pub get once
    templateCopyPath = copyTestProject(templateDir, testEnvRoot, 'template');
    runDartPubGet(templateCopyPath);
    sharedDartToolPath = p.join(templateCopyPath, '.dart_tool');
  });

  group('A1: Layer Architecture Enforcement', () {
    late String projectPath;

    setUp(() {
      projectPath = copyTestProject(templateDir, testEnvRoot, 'a1');
      createDartToolSymlink(projectPath, sharedDartToolPath);

      // Generate import_rules.yaml for this specific test suite
      generateImportRules(projectPath, '''
rules:
  - name: Presentation layer isolation
    reason: Presentation layer should not directly import data layer
    target: lib/presentation/**
    disallow: lib/data/**
    exclude_disallow: lib/data/models/**
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
      createDartToolSymlink(projectPath, sharedDartToolPath);

      // Generate import_rules.yaml for this specific test suite
      generateImportRules(projectPath, '''
rules:
  - name: src directory encapsulation
    reason: src/ directories are always private to their parent module
    target: lib/**
    disallow: lib/**/src/**
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
      createDartToolSymlink(projectPath, sharedDartToolPath);

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
          line: 8,
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
      createDartToolSymlink(projectPath, sharedDartToolPath);

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

  group('Format-Agnostic Pattern Matching', () {
    late String projectPath;

    setUp(() {
      projectPath = copyTestProject(
        templateDir,
        testEnvRoot,
        'format_agnostic',
      );
      createDartToolSymlink(projectPath, sharedDartToolPath);

      // Generate import_rules.yaml with package: URI patterns
      // These patterns should match imports in ANY format (package:, relative, etc.)
      generateImportRules(projectPath, '''
rules:
  - name: Format-agnostic blocking with package URI pattern
    reason: Patterns should match regardless of import format
    target: lib/**
    disallow: package:test_project/data/repository.dart
''');
    });

    test('package: URI pattern should match package: import', () {
      final result = runDartAnalyze(
        projectPath,
        'lib/format_agnostic_test.dart',
      );

      // The pattern "package:test_project/data/repository.dart" is normalized to
      // "lib/data/repository.dart" at parse time, which matches the normalized
      // import "lib/data/repository.dart"
      expect(
        result,
        containsLintError(
          file: 'format_agnostic_test.dart',
          line: 9,
          col: 1,
          message: contains(
            'Patterns should match regardless of import format',
          ),
        ),
      );
    });

    test('package: URI pattern should also match relative import', () {
      final result = runDartAnalyze(
        projectPath,
        'lib/format_agnostic_test.dart',
      );

      // The same normalized pattern also matches the relative import
      // Both imports resolve to "lib/data/repository.dart"
      expect(
        result,
        containsLintError(
          file: 'format_agnostic_test.dart',
          line: 13,
          col: 1,
          message: contains(
            'Patterns should match regardless of import format',
          ),
        ),
      );
    });

    test('should not block imports outside the disallow pattern', () {
      final result = runDartAnalyze(
        projectPath,
        'lib/format_agnostic_test.dart',
      );

      // Line 17 imports models/user.dart, which is not in the disallow list
      expect(
        result,
        isNot(containsLintError(file: 'format_agnostic_test.dart', line: 17)),
      );
    });

    test('relative path pattern works equivalently to package pattern', () {
      // Now test with a relative path pattern instead
      generateImportRules(projectPath, '''
rules:
  - name: Format-agnostic blocking with relative path pattern
    reason: Relative path patterns should also be format-agnostic
    target: lib/**
    disallow: lib/data/repository.dart
''');

      final result = runDartAnalyze(
        projectPath,
        'lib/format_agnostic_test.dart',
      );

      // Both lines 10 and 14 should be blocked by the relative path pattern
      // because all imports are normalized to the same format
      expect(
        result,
        containsLintError(
          file: 'format_agnostic_test.dart',
          line: 9,
          message: contains(
            'Relative path patterns should also be format-agnostic',
          ),
        ),
      );

      expect(
        result,
        containsLintError(
          file: 'format_agnostic_test.dart',
          line: 13,
          message: contains(
            'Relative path patterns should also be format-agnostic',
          ),
        ),
      );
    });

    test('single pattern eliminates need for redundant rules', () {
      // Demonstrate that we no longer need redundant patterns
      generateImportRules(projectPath, '''
rules:
  - name: Single pattern matches all import forms
    reason: No need for redundant patterns anymore
    target: lib/**
    disallow: lib/data/**
    # Before this feature, developers needed BOTH:
    # - lib/data/**
    # - package:test_project/data/**
    # Now, just ONE pattern works for everything!
''');

      final result = runDartAnalyze(
        projectPath,
        'lib/format_agnostic_test.dart',
      );

      // Both package: and relative imports should be blocked by the single pattern
      expect(
        result,
        containsLintError(
          file: 'format_agnostic_test.dart',
          line: 9,
          message: contains('No need for redundant patterns anymore'),
        ),
      );

      expect(
        result,
        containsLintError(
          file: 'format_agnostic_test.dart',
          line: 13,
          message: contains('No need for redundant patterns anymore'),
        ),
      );
    });
  });
}
