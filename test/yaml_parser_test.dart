import 'dart:io';

import 'package:import_rules/src/import_rules.dart';
import 'package:import_rules/src/parser.dart';
import 'package:test/test.dart';

void main() {
  group('parseRulesFromYaml', () {
    test('parses simple rule with single string values', () {
      final yaml = '''
rules:
  - name: Test rule
    reason: Testing
    target: lib/**
    disallow: test/**
''';

      final rules = parseRulesFromYaml(yaml);

      expect(rules, hasLength(1));
      expect(rules[0].name, equals('Test rule'));
      expect(rules[0].reason, equals('Testing'));
      expect(rules[0].target, equals(['lib/**']));
      expect(rules[0].disallow, equals(['test/**']));
      expect(rules[0].excludeTarget, isEmpty);
      expect(rules[0].excludeDisallow, isEmpty);
    });

    test('parses rule with array values', () {
      final yaml = '''
rules:
  - reason: Testing
    target:
      - lib/features/**
      - lib/ui/**
    disallow:
      - lib/data/**
      - lib/internal/**
''';

      final rules = parseRulesFromYaml(yaml);

      expect(rules, hasLength(1));
      expect(rules[0].target, equals(['lib/features/**', 'lib/ui/**']));
      expect(rules[0].disallow, equals(['lib/data/**', 'lib/internal/**']));
    });

    test('parses rule with all optional fields', () {
      final yaml = '''
rules:
  - name: Complete rule
    reason: Testing all fields
    target: lib/**
    exclude_target: lib/core/**
    disallow: package:flutter/**
    exclude_disallow: package:flutter/material.dart
''';

      final rules = parseRulesFromYaml(yaml);

      expect(rules, hasLength(1));
      expect(rules[0].name, equals('Complete rule'));
      expect(rules[0].excludeTarget, equals(['lib/core/**']));
      expect(
        rules[0].excludeDisallow,
        equals(['package:flutter/material.dart']),
      );
    });

    test('parses multiple rules', () {
      final yaml = '''
rules:
  - name: Rule 1
    reason: First rule
    target: lib/features/**
    disallow: lib/data/**
  - name: Rule 2
    reason: Second rule
    target: lib/core/**
    disallow: package:flutter/**
  - name: Rule 3
    reason: Third rule
    target: test/**
    disallow: lib/internal/**
''';

      final rules = parseRulesFromYaml(yaml);

      expect(rules, hasLength(3));
      expect(rules[0].name, equals('Rule 1'));
      expect(rules[1].name, equals('Rule 2'));
      expect(rules[2].name, equals('Rule 3'));
    });

    test('parses rule without name field', () {
      final yaml = '''
rules:
  - reason: Anonymous rule
    target: lib/**
    disallow: test/**
''';

      final rules = parseRulesFromYaml(yaml);

      expect(rules, hasLength(1));
      expect(rules[0].name, isNull);
      expect(rules[0].reason, equals('Anonymous rule'));
    });

    test('parses rule with mixed single and array values', () {
      final yaml = '''
rules:
  - reason: Mixed values
    target: lib/**
    exclude_target:
      - lib/core/**
      - lib/shared/**
    disallow: package:flutter/**
    exclude_disallow: package:flutter/material.dart
''';

      final rules = parseRulesFromYaml(yaml);

      expect(rules, hasLength(1));
      expect(rules[0].target, equals(['lib/**']));
      expect(rules[0].excludeTarget, equals(['lib/core/**', 'lib/shared/**']));
      expect(rules[0].disallow, equals(['package:flutter/**']));
      expect(
        rules[0].excludeDisallow,
        equals(['package:flutter/material.dart']),
      );
    });

    test('parses rule with \$DIR placeholder', () {
      final yaml = r'''
rules:
  - reason: DIR test
    target: "**"
    disallow: "**/src/**"
    exclude_disallow: "$DIR/**"
''';

      final rules = parseRulesFromYaml(yaml);

      expect(rules, hasLength(1));
      expect(rules[0].excludeDisallow, equals([r'$DIR/**']));
    });
  });

  group('parseRulesFromYaml - error handling', () {
    test('throws on empty YAML', () {
      expect(
        () => parseRulesFromYaml(''),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('empty'),
          ),
        ),
      );
    });

    test('throws on missing rules key', () {
      final yaml = '''
some_other_key:
  - value: test
''';

      expect(
        () => parseRulesFromYaml(yaml),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('rules'),
          ),
        ),
      );
    });

    test('throws when rules is not a list', () {
      final yaml = '''
rules: not_a_list
''';

      expect(
        () => parseRulesFromYaml(yaml),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('must be a list'),
          ),
        ),
      );
    });

    test('throws on missing reason field', () {
      final yaml = '''
rules:
  - name: Test rule
    target: lib/**
    disallow: test/**
''';

      expect(
        () => parseRulesFromYaml(yaml),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('reason'),
          ),
        ),
      );
    });

    test('throws on missing target field', () {
      final yaml = '''
rules:
  - reason: Test
    disallow: test/**
''';

      expect(
        () => parseRulesFromYaml(yaml),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('target'),
          ),
        ),
      );
    });

    test('throws on missing disallow field', () {
      final yaml = '''
rules:
  - reason: Test
    target: lib/**
''';

      expect(
        () => parseRulesFromYaml(yaml),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('disallow'),
          ),
        ),
      );
    });

    test('throws when target is not a string or list', () {
      final yaml = '''
rules:
  - reason: Test
    target: 123
    disallow: test/**
''';

      expect(
        () => parseRulesFromYaml(yaml),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('target'),
          ),
        ),
      );
    });

    test('throws when target list contains non-string', () {
      final yaml = '''
rules:
  - reason: Test
    target:
      - lib/**
      - 123
    disallow: test/**
''';

      expect(
        () => parseRulesFromYaml(yaml),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('target'),
          ),
        ),
      );
    });

    test('throws when disallow is not a string or list', () {
      final yaml = '''
rules:
  - reason: Test
    target: lib/**
    disallow: 123
''';

      expect(
        () => parseRulesFromYaml(yaml),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('disallow'),
          ),
        ),
      );
    });

    test('throws when reason is not a string', () {
      final yaml = '''
rules:
  - reason: 123
    target: lib/**
    disallow: test/**
''';

      expect(
        () => parseRulesFromYaml(yaml),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('reason'),
          ),
        ),
      );
    });

    test('throws when rule is not a map', () {
      final yaml = '''
rules:
  - not_a_map
''';

      expect(
        () => parseRulesFromYaml(yaml),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('must be a map'),
          ),
        ),
      );
    });

    test('includes rule index in error message', () {
      final yaml = '''
rules:
  - reason: Valid rule
    target: lib/**
    disallow: test/**
  - reason: Invalid rule
    target: lib/**
    # missing disallow
  - reason: Another valid rule
    target: lib/**
    disallow: test/**
''';

      expect(
        () => parseRulesFromYaml(yaml),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('index 1'),
          ),
        ),
      );
    });
  });

  group('parseRulesFromYamlFile', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('import_rules_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('reads and parses YAML file', () {
      final file = File('${tempDir.path}/test_rules.yaml');
      file.writeAsStringSync('''
rules:
  - name: File test
    reason: Testing file parsing
    target: lib/**
    disallow: test/**
''');

      final rules = parseRulesFromYamlFile(file.path);

      expect(rules, hasLength(1));
      expect(rules[0].name, equals('File test'));
      expect(rules[0].reason, equals('Testing file parsing'));
    });

    test('throws when file does not exist', () {
      expect(
        () => parseRulesFromYamlFile('${tempDir.path}/nonexistent.yaml'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('throws when file contains invalid YAML', () {
      final file = File('${tempDir.path}/invalid.yaml');
      file.writeAsStringSync('''
rules:
  - reason: Test
    target: lib/**
    # missing disallow
''');

      expect(
        () => parseRulesFromYamlFile(file.path),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('\$DIR placeholder validation', () {
    test('throws when \$DIR is used in target field (single string)', () {
      final yaml = r'''
rules:
  - reason: Invalid rule
    target: "$DIR/**"
    disallow: test/**
''';

      expect(
        () => parseRulesFromYaml(yaml),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(r'$DIR placeholder cannot be used in "target" field'),
          ),
        ),
      );
    });

    test('throws when \$DIR is used in target field (array)', () {
      final yaml = r'''
rules:
  - reason: Invalid rule
    target:
      - lib/**
      - "$DIR/src/**"
    disallow: test/**
''';

      expect(
        () => parseRulesFromYaml(yaml),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(r'$DIR placeholder cannot be used in "target" field'),
          ),
        ),
      );
    });

    test(
      'throws when \$DIR is used in exclude_target field (single string)',
      () {
        final yaml = r'''
rules:
  - reason: Invalid rule
    target: lib/**
    exclude_target: "$DIR/**"
    disallow: test/**
''';

        expect(
          () => parseRulesFromYaml(yaml),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains(
                r'$DIR placeholder cannot be used in "exclude_target" field',
              ),
            ),
          ),
        );
      },
    );

    test('throws when \$DIR is used in exclude_target field (array)', () {
      final yaml = r'''
rules:
  - reason: Invalid rule
    target: lib/**
    exclude_target:
      - lib/core/**
      - "$DIR/shared/**"
    disallow: test/**
''';

      expect(
        () => parseRulesFromYaml(yaml),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(
              r'$DIR placeholder cannot be used in "exclude_target" field',
            ),
          ),
        ),
      );
    });

    test('allows \$DIR in disallow field', () {
      final yaml = r'''
rules:
  - reason: Valid rule
    target: lib/**
    disallow: "$DIR/**"
''';

      // Should not throw
      final rules = parseRulesFromYaml(yaml);
      expect(rules, hasLength(1));
      expect(rules[0].disallow, equals([r'$DIR/**']));
    });

    test('allows \$DIR in exclude_disallow field', () {
      final yaml = r'''
rules:
  - reason: Valid rule
    target: lib/**
    disallow: "**/src/**"
    exclude_disallow: "$DIR/**"
''';

      // Should not throw
      final rules = parseRulesFromYaml(yaml);
      expect(rules, hasLength(1));
      expect(rules[0].excludeDisallow, equals([r'$DIR/**']));
    });
  });

  group('\$DIR with multiple target patterns', () {
    test('\$DIR works correctly with single target pattern', () {
      final yaml = r'''
rules:
  - reason: Test single target
    target: lib/features/auth/**
    disallow: "**/src/**"
    exclude_disallow: "$DIR/**"
''';

      final rules = parseRulesFromYaml(yaml);
      expect(rules, hasLength(1));

      // File in lib/features/auth/src can import from same src
      expect(
        canImport(
          'lib/features/auth/src/cache.dart',
          'lib/features/auth/src/utils.dart',
          rules[0],
        ),
        isTrue,
      );

      // File in lib/features/auth can import from its src
      expect(
        canImport(
          'lib/features/auth/auth.dart',
          'lib/features/auth/src/utils.dart',
          rules[0],
        ),
        isTrue,
      );
    });

    test('\$DIR works correctly with multiple target patterns', () {
      final yaml = r'''
rules:
  - reason: Test multiple targets
    target:
      - lib/features/auth/**
      - lib/features/profile/**
      - lib/features/settings/**
    disallow: "**/src/**"
    exclude_disallow: "$DIR/**"
''';

      final rules = parseRulesFromYaml(yaml);
      expect(rules, hasLength(1));

      // Auth file can import from auth src
      expect(
        canImport(
          'lib/features/auth/auth.dart',
          'lib/features/auth/src/utils.dart',
          rules[0],
        ),
        isTrue,
      );

      // Profile file can import from profile src
      expect(
        canImport(
          'lib/features/profile/profile.dart',
          'lib/features/profile/src/utils.dart',
          rules[0],
        ),
        isTrue,
      );

      // Settings file can import from settings src
      expect(
        canImport(
          'lib/features/settings/settings.dart',
          'lib/features/settings/src/utils.dart',
          rules[0],
        ),
        isTrue,
      );

      // Auth file cannot import from profile src (different module)
      expect(
        canImport(
          'lib/features/auth/auth.dart',
          'lib/features/profile/src/utils.dart',
          rules[0],
        ),
        isFalse,
      );

      // Profile file cannot import from settings src (different module)
      expect(
        canImport(
          'lib/features/profile/profile.dart',
          'lib/features/settings/src/utils.dart',
          rules[0],
        ),
        isFalse,
      );
    });

    test('\$DIR is evaluated per matched file, not per target pattern', () {
      final yaml = r'''
rules:
  - reason: DIR is file-specific
    target:
      - lib/features/auth/**
      - lib/core/**
    disallow: "**"
    exclude_disallow: "$DIR/**"
''';

      final rules = parseRulesFromYaml(yaml);
      expect(rules, hasLength(1));

      // Auth file has DIR=lib/features/auth
      expect(
        canImport(
          'lib/features/auth/login.dart',
          'lib/features/auth/models/user.dart',
          rules[0],
        ),
        isTrue,
      );
      expect(
        canImport(
          'lib/features/auth/login.dart',
          'lib/core/entity.dart',
          rules[0],
        ),
        isFalse,
      );

      // Core file has DIR=lib/core
      expect(
        canImport('lib/core/entity.dart', 'lib/core/value.dart', rules[0]),
        isTrue,
      );
      expect(
        canImport(
          'lib/core/entity.dart',
          'lib/features/auth/login.dart',
          rules[0],
        ),
        isFalse,
      );
    });
  });

  group('Real-world examples from spec', () {
    test('parses Layer Architecture Enforcement example', () {
      final yaml = '''
rules:
  - name: Presentation layer isolation
    reason: Presentation layer should not directly import data layer
    target: lib/presentation/**
    disallow: lib/data/**
    exclude_disallow: lib/data/models/**
''';

      final rules = parseRulesFromYaml(yaml);

      expect(rules, hasLength(1));
      expect(rules[0].name, equals('Presentation layer isolation'));
      expect(
        canImport(
          'lib/presentation/pages/home.dart',
          'lib/data/models/user.dart',
          rules[0],
        ),
        isTrue,
      );
      expect(
        canImport(
          'lib/presentation/pages/home.dart',
          'lib/data/repositories/user_repository.dart',
          rules[0],
        ),
        isFalse,
      );
    });

    test('parses src Directory Encapsulation example', () {
      final yaml = r'''
rules:
  - name: src directory encapsulation
    reason: src/ directories are always private to their parent module
    target: "**"
    disallow: "**/src/**"
    exclude_disallow: "$DIR/**"
''';

      final rules = parseRulesFromYaml(yaml);

      expect(rules, hasLength(1));
      expect(
        canImport(
          'lib/features/auth/auth.dart',
          'lib/features/auth/src/utils.dart',
          rules[0],
        ),
        isTrue,
      );
      expect(
        canImport(
          'lib/infrastructure/db.dart',
          'lib/domain/src/entity.dart',
          rules[0],
        ),
        isFalse,
      );
    });

    test('parses Core Domain Independence example', () {
      final yaml = '''
rules:
  - name: Core independence
    reason: Core domain must remain framework-agnostic
    target: lib/core/**
    disallow:
      - package:flutter/**
      - lib/ui/**
''';

      final rules = parseRulesFromYaml(yaml);

      expect(rules, hasLength(1));
      expect(rules[0].disallow, hasLength(2));
      expect(
        canImport(
          'lib/core/entities/user.dart',
          'package:flutter/material.dart',
          rules[0],
        ),
        isFalse,
      );
    });

    test('parses multiple rules from spec', () {
      final yaml = '''
rules:
  - name: Presentation layer isolation
    reason: Presentation layer should not directly import data layer
    target: lib/presentation/**
    disallow: lib/data/**
    exclude_disallow: lib/data/models/**

  - name: Core independence
    reason: Core domain must remain framework-agnostic
    target: lib/core/**
    disallow:
      - package:flutter/**
      - lib/ui/**

  - name: Feature module boundaries
    reason: Features should not cross-import each other
    target: lib/features/auth/**
    disallow:
      - lib/features/profile/**
      - lib/features/settings/**
      - lib/features/cart/**
''';

      final rules = parseRulesFromYaml(yaml);

      expect(rules, hasLength(3));
      expect(rules[0].name, equals('Presentation layer isolation'));
      expect(rules[1].name, equals('Core independence'));
      expect(rules[2].name, equals('Feature module boundaries'));
    });
  });
}
