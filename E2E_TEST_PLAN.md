# E2E Test Implementation Plan

## Overview
Build end-to-end tests for the import_rules Dart analyzer plugin that verify the full integration: YAML config → analyzer plugin → lint error reporting.

## 1. Project Structure

```
import_rules/
├── e2e/
│   ├── test_project/          # Template Dart project with intentional violations
│   │   ├── lib/
│   │   │   ├── presentation/  # A1: Layer architecture test files
│   │   │   ├── core/          # A2: Core independence test files
│   │   │   ├── features/      # A3: Feature boundaries test files
│   │   │   │   ├── auth/
│   │   │   │   ├── profile/
│   │   │   │   └── settings/
│   │   │   └── ...            # More directories for A4-A11
│   │   ├── test/              # A5: Test isolation test files
│   │   ├── pubspec.yaml
│   │   └── analysis_options.yaml  # References ../../ plugin
│   ├── src/                   # Helper utilities for e2e tests
│   │   ├── analyzer_output.dart   # AnalyzerOutput and LintError classes
│   │   ├── test_helpers.dart      # Helper functions (copy, run commands, etc.)
│   │   └── matchers.dart          # Custom test matchers
│   ├── test/                  # Unit tests for e2e infrastructure
│   │   └── src/
│   │       ├── matchers_test.dart      # Tests for custom matchers
│   │       └── analyzer_output_test.dart  # Tests for analyzer output parsing
│   └── e2e_test.dart          # Main test runner
├── .e2e/                      # Test environment (gitignored)
│   └── [copied projects]      # Isolated test executions (with generated import_rules.yaml)
└── .gitignore                 # Add .e2e/
```

## 2. Create Test Project Template

### 2.1 Initialize Project
```bash
cd e2e/
fvm dart create test_project
cd test_project
```

### 2.2 Configure Plugin (`e2e/test_project/analysis_options.yaml`)
```yaml
include: package:lints/recommended.yaml

plugins:
  import_rules:
    path: ../../  # Reference parent plugin
```

**Note:** Do NOT create `import_rules.yaml` in the template project. Each test suite will dynamically generate its own `import_rules.yaml` containing only the rules it needs to test.

### 2.3 Create Test Suite Files
One file per use case, containing imports that should trigger violations:

**Example - A1 (Layer Architecture):**
```dart
// lib/presentation/a1_layer_arch.dart
import 'package:test_project/data/repository.dart';  // Should violate
import 'package:test_project/data/models/user.dart'; // Should be allowed (exclude)
```

**Example - A4 (src Encapsulation):**
```dart
// lib/features/auth/auth.dart
import 'package:test_project/features/auth/src/utils.dart';     // Allowed (same module)
import 'package:test_project/features/profile/src/helper.dart'; // Violates
```

### 2.4 Create Dependency Files
Create actual Dart files that test suites import:
```dart
// lib/data/repository.dart
class Repository {}

// lib/data/models/user.dart
class User {}

// lib/features/auth/src/utils.dart
void authUtil() {}
```

Ensure these files have minimal content to avoid unrelated lint errors.

## 3. Test Runner Implementation

### 3.1 File: `e2e/e2e_test.dart`

Main test file that imports helpers and defines test suites:

```dart
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
      final result = runDartAnalyze(projectPath, 'lib/presentation/a1_layer_arch.dart');

      expect(result, containsLintError(
        file: 'lib/presentation/a1_layer_arch.dart',
        line: 2,
        col: 1,
        message: contains('Presentation layer should not directly import data layer'),
      ));
    });

    test('should allow presentation → data/models imports', () {
      final result = runDartAnalyze(projectPath, 'lib/presentation/a1_layer_arch.dart');

      expect(result, isNot(containsLintError(
        file: 'lib/presentation/a1_layer_arch.dart',
        line: 3,
      )));
    });
  });

  // Similar groups for A2-A11...
}
```

### 3.2 File: `e2e/src/analyzer_output.dart`

Classes for parsing and representing analyzer output:

```dart
/// Represents the parsed output from dart analyze command
class AnalyzerOutput {
  final List<LintError> errors;

  AnalyzerOutput(this.errors);

  static AnalyzerOutput parse(String output) {
    final errors = <LintError>[];
    // Parse format: "   info - lib/main.dart:5:1 - Message - code"
    final regex = RegExp(r'^\s+\w+ - ([^:]+):(\d+):(\d+) - (.+?) - (\w+)$', multiLine: true);

    for (final match in regex.allMatches(output)) {
      errors.add(LintError(
        file: match.group(1)!,
        line: int.parse(match.group(2)!),
        col: int.parse(match.group(3)!),
        message: match.group(4)!,
        code: match.group(5)!,
      ));
    }

    return AnalyzerOutput(errors);
  }
}

/// Represents a single lint error from analyzer output
class LintError {
  final String file;
  final int line;
  final int col;
  final String message;
  final String code;

  LintError({
    required this.file,
    required this.line,
    required this.col,
    required this.message,
    required this.code,
  });

  @override
  String toString() => '$file:$line:$col - $message ($code)';
}
```

### 3.3 File: `e2e/src/test_helpers.dart`

Helper functions for test project management and running commands:

```dart
import 'dart:io';
import 'package:path/path.dart' as p;

import 'analyzer_output.dart';

/// Copies the test project template to a new location
String copyTestProject(String src, String destRoot, String name) {
  final dest = p.join(destRoot, 'test_project_$name');
  _copyDirectory(Directory(src), Directory(dest), excludeDirs: {'.dart_tool', 'build'});
  return dest;
}

void _copyDirectory(Directory src, Directory dest, {Set<String> excludeDirs = const {}}) {
  dest.createSync(recursive: true);
  for (final entity in src.listSync()) {
    final name = p.basename(entity.path);
    if (excludeDirs.contains(name)) continue;

    if (entity is File) {
      entity.copySync(p.join(dest.path, name));
    } else if (entity is Directory) {
      _copyDirectory(entity, Directory(p.join(dest.path, name)), excludeDirs: excludeDirs);
    }
  }
}

/// Generates import_rules.yaml in the specified project
void generateImportRules(String projectPath, String yamlContent) {
  final rulesFile = File(p.join(projectPath, 'import_rules.yaml'));
  rulesFile.writeAsStringSync(yamlContent);
}

/// Runs dart pub get in the specified project
void runDartPubGet(String projectPath) {
  final result = Process.runSync(
    'fvm',
    ['dart', 'pub', 'get'],
    workingDirectory: projectPath,
  );
  if (result.exitCode != 0) {
    throw Exception('dart pub get failed: ${result.stderr}');
  }
}

/// Runs dart analyze on a specific file and returns parsed output
AnalyzerOutput runDartAnalyze(String projectPath, String targetFile) {
  final result = Process.runSync(
    'fvm',
    ['dart', 'analyze', targetFile],
    workingDirectory: projectPath,
  );
  return AnalyzerOutput.parse(result.stdout.toString());
}
```

### 3.4 File: `e2e/src/matchers.dart`

Custom test matchers for verifying analyzer output:

```dart
import 'package:test/test.dart';
import 'analyzer_output.dart';

/// Matcher that checks if analyzer output contains a specific lint error
Matcher containsLintError({
  required String file,
  int? line,
  int? col,
  Matcher? message,
}) {
  return predicate<AnalyzerOutput>((output) {
    return output.errors.any((error) =>
      error.file == file &&
      (line == null || error.line == line) &&
      (col == null || error.col == col) &&
      (message == null || message.matches(error.message, {}))
    );
  }, 'contains lint error in $file${line != null ? ':$line' : ''}${col != null ? ':$col' : ''}');
}
```

## 4. Unit Tests for E2E Infrastructure

Before running the full e2e tests, verify that the test infrastructure itself works correctly.

### 4.1 File: `e2e/test/src/matchers_test.dart`

Unit tests for custom matchers:

```dart
import 'package:test/test.dart';
import '../../src/analyzer_output.dart';
import '../../src/matchers.dart';

void main() {
  group('containsLintError matcher', () {
    test('matches when error exists with exact file, line, and col', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/main.dart',
          line: 5,
          col: 1,
          message: 'Import rule violation. Do not import this.',
          code: 'import_rule_violation',
        ),
      ]);

      expect(
        output,
        containsLintError(
          file: 'lib/main.dart',
          line: 5,
          col: 1,
        ),
      );
    });

    test('matches when error exists with file only', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/main.dart',
          line: 5,
          col: 1,
          message: 'Import rule violation.',
          code: 'import_rule_violation',
        ),
      ]);

      expect(
        output,
        containsLintError(file: 'lib/main.dart'),
      );
    });

    test('matches when error exists with file and line only', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/main.dart',
          line: 5,
          col: 1,
          message: 'Import rule violation.',
          code: 'import_rule_violation',
        ),
      ]);

      expect(
        output,
        containsLintError(
          file: 'lib/main.dart',
          line: 5,
        ),
      );
    });

    test('matches when message contains expected text', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/main.dart',
          line: 5,
          col: 1,
          message: 'Import rule violation. Presentation layer should not import data layer.',
          code: 'import_rule_violation',
        ),
      ]);

      expect(
        output,
        containsLintError(
          file: 'lib/main.dart',
          message: contains('Presentation layer should not import data layer'),
        ),
      );
    });

    test('does not match when file is different', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/main.dart',
          line: 5,
          col: 1,
          message: 'Import rule violation.',
          code: 'import_rule_violation',
        ),
      ]);

      expect(
        output,
        isNot(containsLintError(file: 'lib/other.dart')),
      );
    });

    test('does not match when line is different', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/main.dart',
          line: 5,
          col: 1,
          message: 'Import rule violation.',
          code: 'import_rule_violation',
        ),
      ]);

      expect(
        output,
        isNot(containsLintError(
          file: 'lib/main.dart',
          line: 10,
        )),
      );
    });

    test('does not match when col is different', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/main.dart',
          line: 5,
          col: 1,
          message: 'Import rule violation.',
          code: 'import_rule_violation',
        ),
      ]);

      expect(
        output,
        isNot(containsLintError(
          file: 'lib/main.dart',
          line: 5,
          col: 8,
        )),
      );
    });

    test('does not match when message does not contain expected text', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/main.dart',
          line: 5,
          col: 1,
          message: 'Import rule violation. Some other reason.',
          code: 'import_rule_violation',
        ),
      ]);

      expect(
        output,
        isNot(containsLintError(
          file: 'lib/main.dart',
          message: contains('expected text not present'),
        )),
      );
    });

    test('matches one of multiple errors', () {
      final output = AnalyzerOutput([
        LintError(
          file: 'lib/main.dart',
          line: 5,
          col: 1,
          message: 'First error',
          code: 'import_rule_violation',
        ),
        LintError(
          file: 'lib/other.dart',
          line: 10,
          col: 1,
          message: 'Second error',
          code: 'import_rule_violation',
        ),
      ]);

      expect(
        output,
        containsLintError(file: 'lib/other.dart', line: 10),
      );
    });

    test('does not match when output is empty', () {
      final output = AnalyzerOutput([]);

      expect(
        output,
        isNot(containsLintError(file: 'lib/main.dart')),
      );
    });
  });
}
```

### 4.2 File: `e2e/test/src/analyzer_output_test.dart`

Unit tests for analyzer output parsing:

```dart
import 'package:test/test.dart';
import '../../src/analyzer_output.dart';

void main() {
  group('AnalyzerOutput.parse', () {
    test('parses single error correctly', () {
      final output = '''
Analyzing test_project...

   info - lib/main.dart:5:1 - Import rule violation. Do not import this. - import_rule_violation

1 issue found.
''';

      final result = AnalyzerOutput.parse(output);

      expect(result.errors.length, 1);
      expect(result.errors[0].file, 'lib/main.dart');
      expect(result.errors[0].line, 5);
      expect(result.errors[0].col, 1);
      expect(result.errors[0].message, 'Import rule violation. Do not import this.');
      expect(result.errors[0].code, 'import_rule_violation');
    });

    test('parses multiple errors correctly', () {
      final output = '''
Analyzing test_project...

   info - lib/main.dart:5:1 - Import rule violation. First error. - import_rule_violation
   info - lib/other.dart:10:8 - Import rule violation. Second error. - import_rule_violation

2 issues found.
''';

      final result = AnalyzerOutput.parse(output);

      expect(result.errors.length, 2);

      expect(result.errors[0].file, 'lib/main.dart');
      expect(result.errors[0].line, 5);
      expect(result.errors[0].col, 1);

      expect(result.errors[1].file, 'lib/other.dart');
      expect(result.errors[1].line, 10);
      expect(result.errors[1].col, 8);
    });

    test('returns empty list when no errors', () {
      final output = '''
Analyzing test_project...

No issues found.
''';

      final result = AnalyzerOutput.parse(output);

      expect(result.errors, isEmpty);
    });

    test('handles nested file paths', () {
      final output = '''
   info - lib/features/auth/src/utils.dart:15:1 - Import rule violation. Message. - import_rule_violation
''';

      final result = AnalyzerOutput.parse(output);

      expect(result.errors.length, 1);
      expect(result.errors[0].file, 'lib/features/auth/src/utils.dart');
      expect(result.errors[0].line, 15);
    });

    test('ignores non-error lines', () {
      final output = '''
Analyzing test_project...

Some other output line
   info - lib/main.dart:5:1 - Import rule violation. Message. - import_rule_violation
Another line of output

1 issue found.
''';

      final result = AnalyzerOutput.parse(output);

      expect(result.errors.length, 1);
      expect(result.errors[0].file, 'lib/main.dart');
    });

    test('handles different severity levels', () {
      final output = '''
   warning - lib/main.dart:5:1 - Import rule violation. Message. - import_rule_violation
   error - lib/other.dart:10:1 - Import rule violation. Message. - import_rule_violation
''';

      final result = AnalyzerOutput.parse(output);

      expect(result.errors.length, 2);
    });
  });

  group('LintError.toString', () {
    test('formats error correctly', () {
      final error = LintError(
        file: 'lib/main.dart',
        line: 5,
        col: 1,
        message: 'Import rule violation.',
        code: 'import_rule_violation',
      );

      expect(
        error.toString(),
        'lib/main.dart:5:1 - Import rule violation. (import_rule_violation)',
      );
    });
  });
}
```

## 5. Implementation Checklist

### Phase 1: Setup Test Project Template
- [ ] Create `e2e/` directory structure
- [ ] Run `fvm dart create test_project` in `e2e/`
- [ ] Configure `e2e/test_project/analysis_options.yaml`
- [ ] Create test suite files for each use case (11 files)
- [ ] Create dependency files to support test suites
- [ ] Verify test project has no compile errors

### Phase 2: Implement E2E Infrastructure
- [ ] Create `e2e/src/` directory with helper utilities:
  - [ ] `e2e/src/analyzer_output.dart` - AnalyzerOutput and LintError classes
  - [ ] `e2e/src/test_helpers.dart` - Helper functions (copy, run commands, generate rules)
  - [ ] `e2e/src/matchers.dart` - Custom test matchers

### Phase 3: Unit Test the Infrastructure
- [ ] Create `e2e/test/src/` directory
- [ ] Implement `e2e/test/src/matchers_test.dart`:
  - [ ] Tests for matcher with exact file/line/col
  - [ ] Tests for matcher with file only
  - [ ] Tests for matcher with message matching
  - [ ] Tests for negative cases (no match)
  - [ ] Tests for multiple errors
  - [ ] Tests for empty output
- [ ] Implement `e2e/test/src/analyzer_output_test.dart`:
  - [ ] Tests for parsing single error
  - [ ] Tests for parsing multiple errors
  - [ ] Tests for empty output
  - [ ] Tests for nested file paths
  - [ ] Tests for different severity levels
  - [ ] Tests for LintError.toString()
- [ ] Run infrastructure unit tests: `fvm dart test e2e/test/`
- [ ] Verify all infrastructure tests pass

### Phase 4: Implement Full E2E Tests
- [ ] Implement `e2e/e2e_test.dart` with:
  - [ ] Test environment setup/cleanup
  - [ ] Test groups for A1-A11 (11 groups, each with dynamically generated import_rules.yaml)
- [ ] Add `.e2e/` to `.gitignore`
- [ ] Run full e2e tests: `fvm dart test e2e/e2e_test.dart`
- [ ] Verify all e2e tests pass

## 6. Verification Strategy

For each use case (A1-A11):
- ✅ Expected violations are reported
- ✅ Violations have correct file paths
- ✅ Violations have correct line/column numbers
- ✅ Violations have correct error messages (matching `reason` field)
- ✅ Allowed imports don't trigger violations
- ✅ No unexpected violations occur

## 7. Notes

### Code Organization
- Helper code is separated into `e2e/src/` directory for better maintainability
- **analyzer_output.dart**: Classes for representing and parsing analyzer output
- **test_helpers.dart**: Functions for project management and running dart commands
- **matchers.dart**: Custom test matchers for cleaner test assertions
- Main test file (`e2e_test.dart`) focuses on test logic, not implementation details

### Infrastructure Testing
- Unit tests for the e2e infrastructure are located in `e2e/test/src/`
- Test the test infrastructure before running full e2e tests
- This ensures that custom matchers and parsers work correctly
- Helps debug issues: if infrastructure tests fail, fix them before running e2e tests
- Run infrastructure tests separately: `fvm dart test e2e/test/`

### Test Isolation
- Each test suite gets its own copied project in `.e2e/test_project_a1/`, etc.
- Each test suite dynamically generates its own `import_rules.yaml` containing only the rules it's testing
- This ensures test isolation and prevents interference between different use cases
- Run `dart pub get` once per copied project
- Analyze specific files, not entire project

### Dynamic Rule Generation
- The template project (`e2e/test_project/`) does NOT contain `import_rules.yaml`
- Each test group's `setUp()` generates a custom `import_rules.yaml` for that specific use case
- This approach:
  - Ensures each test only validates the rules it's designed to test
  - Prevents false positives from unrelated rules
  - Makes tests easier to understand and maintain
  - Allows testing rule combinations and edge cases

### Avoiding False Positives
- Keep dependency files minimal but valid
- Ensure no compile errors
- Disable or suppress unrelated lints if needed

### Output Parsing
- Parse analyzer output format: `level - file:line:col - message - code`
- Filter for `import_rule_violation` code specifically
- Handle multi-line messages if needed
