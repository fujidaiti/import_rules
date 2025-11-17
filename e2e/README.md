# E2E Testing for Import Rules Plugin

End-to-end tests that verify the analyzer plugin works correctly by running `dart analyze` as a subprocess and validating the output.

## How It Works

1. Each test suite gets an isolated copy of `test_project/` in `.e2e/test_project_<name>/`
2. `import_rules.yaml` is generated dynamically in `setUp()` for each test suite
3. `dart analyze` runs on specific files and output is parsed into `AnalyzerOutput`
4. Custom matcher `containsLintError()` verifies expected errors

## Adding New Test Suites

### 1. Create test file in `test_project/lib/` (or `test_project/test/`)

```dart
// test_project/lib/my_feature/test_file.dart
import 'package:test_project/forbidden.dart'; // Should violate

class MyClass {}
```

### 2. Add test group to `e2e_test.dart`

```dart
group('My Test Suite', () {
  late String projectPath;

  setUp(() {
    projectPath = copyTestProject(templateDir, testEnvRoot, 'my_suite');

    generateImportRules(projectPath, '''
rules:
  - name: My rule
    reason: Why this rule exists
    target: package:test_project/my_feature/**
    disallow: package:test_project/forbidden/**
''');

    runDartPubGet(projectPath);
  });

  test('should detect violation', () {
    final result = runDartAnalyze(projectPath, 'lib/my_feature/test_file.dart');

    expect(result, containsLintError(
      file: 'test_file.dart',  // Relative path, not full path
      line: 4,
      message: contains('Why this rule exists'),
    ));
  });
});
```

## Pattern Support

**Currently Working:**
- `package:test_project/**` - Package URI patterns
- `test/**` - File path patterns for test directory
- `$DIR/**` - In `exclude_disallow` only

**Not Yet Supported (TDD - tests fail intentionally):**
- `lib/**` - File path patterns for lib directory

## Key Points

- **File paths in assertions**: Use relative paths (`file.dart`), not full paths (`lib/path/to/file.dart`)
- **Pattern format**: Use `package:test_project/**` for lib files, not `lib/**`
- **Error messages**: Matcher checks that error contains the rule's `reason` text
- **TDD failing tests**: Don't skip them - they document future features
- **Timeout**: Tests use 2-minute timeout due to subprocess execution

## Running Tests

```bash
# All e2e tests
fvm dart test e2e/e2e_test.dart

# Specific test group
fvm dart test e2e/e2e_test.dart --name "Layer Architecture"

# Infrastructure unit tests
fvm dart test e2e/test/
```

## Debugging

- Check instrumentation logs: `.e2e/test_project_<name>/.dart_tool/import_rules/instrumentation_*.log`
- When test fails, `AnalyzerOutput.toString()` shows all found errors or `(no errors)`
