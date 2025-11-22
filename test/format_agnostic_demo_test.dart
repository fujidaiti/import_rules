import 'package:import_rules/src/import_rule.dart';
import 'package:import_rules/src/parser.dart';
import 'package:test/test.dart';

/// Demonstration test showing format-agnostic pattern matching.
///
/// This test demonstrates that a single pattern like `lib/main.dart` can now match
/// imports in different formats:
/// - `import "lib/main.dart"`
/// - `import "package:my_project/main.dart"`
/// - `import "../lib/main.dart"` (resolved to lib/main.dart by the analyzer)
void main() {
  test('format-agnostic matching: single pattern matches all import forms', () {
    // A rule using package: URI pattern
    final yamlWithPackagePattern = '''
rules:
  - name: Demo rule
    reason: Demonstrating format-agnostic patterns
    target: lib/features/**
    disallow: package:my_project/internal.dart
''';

    final config = ConfigParser().parseRulesFromYaml(
      yamlWithPackagePattern,
      'my_project',
    );
    final rule = config.rules.first;

    // The package: pattern was normalized to lib/ at parse time
    expect(rule.disallowPatterns.first.pattern, equals('lib/internal.dart'));
    expect(
      rule.disallowPatterns.first.originalPattern,
      equals('package:my_project/internal.dart'),
    );

    // Now it matches imports in normalized form
    final targetFile = 'lib/features/auth/login.dart';
    final importToCheck = Import(uri: 'lib/internal.dart');

    expect(rule.canImport(targetFile, importToCheck), isFalse);
  });

  test(
    'format-agnostic matching: developers only need one pattern, not redundant rules',
    () {
      // Before this feature, developers had to write redundant patterns like:
      // disallow:
      //   - lib/main.dart
      //   - package:my_project/main.dart
      //
      // Now, a single pattern works for both!

      final yaml = '''
rules:
  - name: Demo rule
    reason: Single pattern matches all forms
    target: test/**
    disallow: lib/src/**
''';

      final config = ConfigParser().parseRulesFromYaml(yaml, 'my_project');
      final rule = config.rules.first;

      final targetFile = 'test/unit/my_test.dart';

      // Both import forms are blocked by the same pattern
      expect(
        rule.canImport(targetFile, Import(uri: 'lib/src/internal.dart')),
        isFalse,
      );
      // This would also be blocked if the import was in package: form,
      // because the analyzer normalizes it to lib/src/internal.dart
    },
  );

  test('external packages and dart: imports remain unchanged', () {
    final yaml = '''
rules:
  - name: Demo rule
    reason: External packages stay as-is
    target: lib/**
    disallow:
      - package:flutter/material.dart
      - dart:mirrors
''';

    final config = ConfigParser().parseRulesFromYaml(yaml, 'my_project');
    final rule = config.rules.first;

    // External packages are NOT normalized
    expect(
      rule.disallowPatterns[0].pattern,
      equals('package:flutter/material.dart'),
    );
    expect(rule.disallowPatterns[1].pattern, equals('dart:mirrors'));
  });
}
