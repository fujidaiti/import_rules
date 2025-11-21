import 'package:import_rules/src/parser.dart';
import 'package:test/test.dart';

void main() {
  group('DisallowPattern normalization', () {
    group('package: URI normalization for current package', () {
      test('normalizes simple package URI to lib/ path', () {
        final yaml = '''
rules:
  - name: Test rule
    reason: Testing normalization
    target: lib/**
    disallow: package:my_project/main.dart
''';

        final config = ConfigParser().parseRulesFromYaml(yaml, 'my_project');
        final rule = config.rules.first;
        final pattern = rule.disallowPatterns.first;

        expect(pattern.pattern, equals('lib/main.dart'));
        expect(pattern.originalPattern, equals('package:my_project/main.dart'));
      });

      test('normalizes nested package URI to lib/ path', () {
        final yaml = '''
rules:
  - name: Test rule
    reason: Testing normalization
    target: lib/**
    disallow: package:my_project/src/config.dart
''';

        final config = ConfigParser().parseRulesFromYaml(yaml, 'my_project');
        final rule = config.rules.first;
        final pattern = rule.disallowPatterns.first;

        expect(pattern.pattern, equals('lib/src/config.dart'));
        expect(
          pattern.originalPattern,
          equals('package:my_project/src/config.dart'),
        );
      });

      test('normalizes deeply nested package URI', () {
        final yaml = '''
rules:
  - name: Test rule
    reason: Testing normalization
    target: lib/**
    disallow: package:import_rules/features/auth/src/utils.dart
''';

        final config = ConfigParser().parseRulesFromYaml(yaml, 'import_rules');
        final rule = config.rules.first;
        final pattern = rule.disallowPatterns.first;

        expect(pattern.pattern, equals('lib/features/auth/src/utils.dart'));
        expect(
          pattern.originalPattern,
          equals('package:import_rules/features/auth/src/utils.dart'),
        );
      });

      test('normalizes glob patterns with package URIs', () {
        final yaml = '''
rules:
  - name: Test rule
    reason: Testing normalization
    target: lib/**
    disallow: package:my_project/src/**
''';

        final config = ConfigParser().parseRulesFromYaml(yaml, 'my_project');
        final rule = config.rules.first;
        final pattern = rule.disallowPatterns.first;

        expect(pattern.pattern, equals('lib/src/**'));
        expect(pattern.originalPattern, equals('package:my_project/src/**'));
      });
    });

    group('external package URIs remain unchanged', () {
      test('keeps external package URI as-is', () {
        final yaml = '''
rules:
  - name: Test rule
    reason: Testing normalization
    target: lib/**
    disallow: package:flutter/material.dart
''';

        final config = ConfigParser().parseRulesFromYaml(yaml, 'my_project');
        final rule = config.rules.first;
        final pattern = rule.disallowPatterns.first;

        expect(pattern.pattern, equals('package:flutter/material.dart'));
        expect(
          pattern.originalPattern,
          equals('package:flutter/material.dart'),
        );
      });

      test('keeps external package glob patterns as-is', () {
        final yaml = '''
rules:
  - name: Test rule
    reason: Testing normalization
    target: lib/**
    disallow: package:flutter/**
''';

        final config = ConfigParser().parseRulesFromYaml(yaml, 'my_project');
        final rule = config.rules.first;
        final pattern = rule.disallowPatterns.first;

        expect(pattern.pattern, equals('package:flutter/**'));
        expect(pattern.originalPattern, equals('package:flutter/**'));
      });
    });

    group('dart: URIs remain unchanged', () {
      test('keeps dart:core as-is', () {
        final yaml = '''
rules:
  - name: Test rule
    reason: Testing normalization
    target: lib/**
    disallow: dart:core
''';

        final config = ConfigParser().parseRulesFromYaml(yaml, 'my_project');
        final rule = config.rules.first;
        final pattern = rule.disallowPatterns.first;

        expect(pattern.pattern, equals('dart:core'));
        expect(pattern.originalPattern, equals('dart:core'));
      });

      test('keeps dart:async as-is', () {
        final yaml = '''
rules:
  - name: Test rule
    reason: Testing normalization
    target: lib/**
    disallow: dart:async
''';

        final config = ConfigParser().parseRulesFromYaml(yaml, 'my_project');
        final rule = config.rules.first;
        final pattern = rule.disallowPatterns.first;

        expect(pattern.pattern, equals('dart:async'));
        expect(pattern.originalPattern, equals('dart:async'));
      });
    });

    group('relative paths remain unchanged', () {
      test('keeps lib/ path as-is', () {
        final yaml = '''
rules:
  - name: Test rule
    reason: Testing normalization
    target: lib/**
    disallow: lib/main.dart
''';

        final config = ConfigParser().parseRulesFromYaml(yaml, 'my_project');
        final rule = config.rules.first;
        final pattern = rule.disallowPatterns.first;

        expect(pattern.pattern, equals('lib/main.dart'));
        expect(pattern.originalPattern, equals('lib/main.dart'));
      });

      test('keeps test/ path as-is', () {
        final yaml = '''
rules:
  - name: Test rule
    reason: Testing normalization
    target: test/**
    disallow: test/helpers/**
''';

        final config = ConfigParser().parseRulesFromYaml(yaml, 'my_project');
        final rule = config.rules.first;
        final pattern = rule.disallowPatterns.first;

        expect(pattern.pattern, equals('test/helpers/**'));
        expect(pattern.originalPattern, equals('test/helpers/**'));
      });

      test('keeps glob patterns as-is', () {
        final yaml = '''
rules:
  - name: Test rule
    reason: Testing normalization
    target: lib/**
    disallow: lib/src/**/*.dart
''';

        final config = ConfigParser().parseRulesFromYaml(yaml, 'my_project');
        final rule = config.rules.first;
        final pattern = rule.disallowPatterns.first;

        expect(pattern.pattern, equals('lib/src/**/*.dart'));
        expect(pattern.originalPattern, equals('lib/src/**/*.dart'));
      });
    });

    group('exclude_disallow normalization', () {
      test('normalizes package URI in exclude_disallow', () {
        final yaml = '''
rules:
  - name: Test rule
    reason: Testing normalization
    target: lib/**
    disallow: lib/**
    exclude_disallow: package:my_project/exceptions.dart
''';

        final config = ConfigParser().parseRulesFromYaml(yaml, 'my_project');
        final rule = config.rules.first;
        final pattern = rule.excludeDisallowPatterns.first;

        expect(pattern.pattern, equals('lib/exceptions.dart'));
        expect(
          pattern.originalPattern,
          equals('package:my_project/exceptions.dart'),
        );
      });

      test('keeps relative path in exclude_disallow as-is', () {
        final yaml = '''
rules:
  - name: Test rule
    reason: Testing normalization
    target: lib/**
    disallow: lib/**
    exclude_disallow: lib/exceptions.dart
''';

        final config = ConfigParser().parseRulesFromYaml(yaml, 'my_project');
        final rule = config.rules.first;
        final pattern = rule.excludeDisallowPatterns.first;

        expect(pattern.pattern, equals('lib/exceptions.dart'));
        expect(pattern.originalPattern, equals('lib/exceptions.dart'));
      });
    });

    group('multiple patterns', () {
      test('normalizes mixed pattern types correctly', () {
        final yaml = '''
rules:
  - name: Test rule
    reason: Testing normalization
    target: lib/**
    disallow:
      - package:my_project/internal.dart
      - lib/src/**
      - package:flutter/**
      - dart:mirrors
''';

        final config = ConfigParser().parseRulesFromYaml(yaml, 'my_project');
        final rule = config.rules.first;
        final patterns = rule.disallowPatterns;

        expect(patterns[0].pattern, equals('lib/internal.dart'));
        expect(
          patterns[0].originalPattern,
          equals('package:my_project/internal.dart'),
        );

        expect(patterns[1].pattern, equals('lib/src/**'));
        expect(patterns[1].originalPattern, equals('lib/src/**'));

        expect(patterns[2].pattern, equals('package:flutter/**'));
        expect(patterns[2].originalPattern, equals('package:flutter/**'));

        expect(patterns[3].pattern, equals('dart:mirrors'));
        expect(patterns[3].originalPattern, equals('dart:mirrors'));
      });
    });

    group(r'$TARGET_DIR placeholder handling', () {
      test(r'normalizes pattern with $TARGET_DIR placeholder', () {
        final yaml = r'''
rules:
  - name: Test rule
    reason: Testing normalization
    target: lib/**
    disallow: package:my_project/$TARGET_DIR/**
''';

        final config = ConfigParser().parseRulesFromYaml(yaml, 'my_project');
        final rule = config.rules.first;
        final pattern = rule.disallowPatterns.first;

        expect(pattern.pattern, equals(r'lib/$TARGET_DIR/**'));
        expect(
          pattern.originalPattern,
          equals(r'package:my_project/$TARGET_DIR/**'),
        );
      });

      test(r'keeps $TARGET_DIR in relative path as-is', () {
        final yaml = r'''
rules:
  - name: Test rule
    reason: Testing normalization
    target: lib/**
    disallow: lib/$TARGET_DIR/src/**
''';

        final config = ConfigParser().parseRulesFromYaml(yaml, 'my_project');
        final rule = config.rules.first;
        final pattern = rule.disallowPatterns.first;

        expect(pattern.pattern, equals(r'lib/$TARGET_DIR/src/**'));
        expect(pattern.originalPattern, equals(r'lib/$TARGET_DIR/src/**'));
      });
    });

    group('no package name provided', () {
      test('patterns remain unchanged when package name is null', () {
        final yaml = '''
rules:
  - name: Test rule
    reason: Testing normalization
    target: lib/**
    disallow:
      - package:my_project/main.dart
      - lib/src/**
''';

        final config = ConfigParser().parseRulesFromYaml(yaml);
        final rule = config.rules.first;
        final patterns = rule.disallowPatterns;

        // Without package name, normalization is disabled
        expect(patterns[0].pattern, equals('package:my_project/main.dart'));
        expect(
          patterns[0].originalPattern,
          equals('package:my_project/main.dart'),
        );

        expect(patterns[1].pattern, equals('lib/src/**'));
        expect(patterns[1].originalPattern, equals('lib/src/**'));
      });
    });
  });
}
