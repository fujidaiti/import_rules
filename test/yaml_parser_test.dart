import 'package:import_rules/src/import_rule.dart';
import 'package:import_rules/src/parser.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigParser().parseRulesFromYaml', () {
    test('parses simple rule with single string values', () {
      final yaml = '''
rules:
  - reason: Testing
    target: lib/**
    disallow: test/**
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(rules[0].reason, equals('Testing'));
      expect(
        rules[0].targetPatterns.map((t) => t.pattern).toList(),
        equals(['lib/**']),
      );
      expect(
        rules[0].disallowPatterns.map((d) => d.pattern).toList(),
        equals(['test/**']),
      );
      expect(
        rules[0].excludeTargetPatterns.map((t) => t.pattern).toList(),
        isEmpty,
      );
      expect(
        rules[0].excludeDisallowPatterns.map((d) => d.pattern).toList(),
        isEmpty,
      );
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

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(
        rules[0].targetPatterns.map((t) => t.pattern).toList(),
        equals(['lib/features/**', 'lib/ui/**']),
      );
      expect(
        rules[0].disallowPatterns.map((d) => d.pattern).toList(),
        equals(['lib/data/**', 'lib/internal/**']),
      );
    });

    test('parses rule with all optional fields', () {
      final yaml = '''
rules:
  - reason: Testing all fields
    target: lib/**
    exclude_target: lib/core/**
    disallow: package:flutter/**
    exclude_disallow: package:flutter/material.dart
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(
        rules[0].excludeTargetPatterns.map((t) => t.pattern).toList(),
        equals(['lib/core/**']),
      );
      expect(
        rules[0].excludeDisallowPatterns.map((d) => d.pattern).toList(),
        equals(['package:flutter/material.dart']),
      );
    });

    test('parses multiple rules', () {
      final yaml = '''
rules:
  - reason: First rule
    target: lib/features/**
    disallow: lib/data/**
  - reason: Second rule
    target: lib/core/**
    disallow: package:flutter/**
  - reason: Third rule
    target: test/**
    disallow: lib/internal/**
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(3));
      expect(rules[0].reason, equals('First rule'));
      expect(rules[1].reason, equals('Second rule'));
      expect(rules[2].reason, equals('Third rule'));
    });

    test('parses rule with only required fields', () {
      final yaml = '''
rules:
  - reason: Simple rule
    target: lib/**
    disallow: test/**
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(rules[0].reason, equals('Simple rule'));
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

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(
        rules[0].targetPatterns.map((t) => t.pattern).toList(),
        equals(['lib/**']),
      );
      expect(
        rules[0].excludeTargetPatterns.map((t) => t.pattern).toList(),
        equals(['lib/core/**', 'lib/shared/**']),
      );
      expect(
        rules[0].disallowPatterns.map((d) => d.pattern).toList(),
        equals(['package:flutter/**']),
      );
      expect(
        rules[0].excludeDisallowPatterns.map((d) => d.pattern).toList(),
        equals(['package:flutter/material.dart']),
      );
    });

    test('parses rule with \$TARGET_DIR placeholder', () {
      final yaml = r'''
rules:
  - reason: TARGET_DIR test
    target: "**"
    disallow: "**/src/**"
    exclude_disallow: "$TARGET_DIR/**"
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(
        rules[0].excludeDisallowPatterns.map((d) => d.pattern).toList(),
        equals([r'$TARGET_DIR/**']),
      );
    });
  });

  group('ConfigParser().parseRulesFromYaml - error handling', () {
    test('throws on empty YAML', () {
      expect(
        () => ConfigParser().parseRulesFromYaml(''),
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
        () => ConfigParser().parseRulesFromYaml(yaml),
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
        () => ConfigParser().parseRulesFromYaml(yaml),
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
  - target: lib/**
    disallow: test/**
''';

      expect(
        () => ConfigParser().parseRulesFromYaml(yaml),
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
        () => ConfigParser().parseRulesFromYaml(yaml),
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
        () => ConfigParser().parseRulesFromYaml(yaml),
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
        () => ConfigParser().parseRulesFromYaml(yaml),
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
        () => ConfigParser().parseRulesFromYaml(yaml),
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
        () => ConfigParser().parseRulesFromYaml(yaml),
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
        () => ConfigParser().parseRulesFromYaml(yaml),
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
        () => ConfigParser().parseRulesFromYaml(yaml),
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
        () => ConfigParser().parseRulesFromYaml(yaml),
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

  group('\$TARGET_DIR placeholder validation', () {
    test(
      'throws when \$TARGET_DIR is used in target field (single string)',
      () {
        final yaml = r'''
rules:
  - reason: Invalid rule
    target: "$TARGET_DIR/**"
    disallow: test/**
''';

        expect(
          () => ConfigParser().parseRulesFromYaml(yaml),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains(
                r'$TARGET_DIR placeholder cannot be used in "target" field',
              ),
            ),
          ),
        );
      },
    );

    test('throws when \$TARGET_DIR is used in target field (array)', () {
      final yaml = r'''
rules:
  - reason: Invalid rule
    target:
      - lib/**
      - "$TARGET_DIR/src/**"
    disallow: test/**
''';

      expect(
        () => ConfigParser().parseRulesFromYaml(yaml),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(
              r'$TARGET_DIR placeholder cannot be used in "target" field',
            ),
          ),
        ),
      );
    });

    test(
      'throws when \$TARGET_DIR is used in exclude_target field (single string)',
      () {
        final yaml = r'''
rules:
  - reason: Invalid rule
    target: lib/**
    exclude_target: "$TARGET_DIR/**"
    disallow: test/**
''';

        expect(
          () => ConfigParser().parseRulesFromYaml(yaml),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains(
                r'$TARGET_DIR placeholder cannot be used in "exclude_target" field',
              ),
            ),
          ),
        );
      },
    );

    test('throws when \$TARGET_DIR is used in exclude_target field (array)', () {
      final yaml = r'''
rules:
  - reason: Invalid rule
    target: lib/**
    exclude_target:
      - lib/core/**
      - "$TARGET_DIR/shared/**"
    disallow: test/**
''';

      expect(
        () => ConfigParser().parseRulesFromYaml(yaml),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(
              r'$TARGET_DIR placeholder cannot be used in "exclude_target" field',
            ),
          ),
        ),
      );
    });

    test('allows \$TARGET_DIR in disallow field', () {
      final yaml = r'''
rules:
  - reason: Valid rule
    target: lib/**
    disallow: "$TARGET_DIR/**"
''';

      // Should not throw
      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;
      expect(rules, hasLength(1));
      expect(
        rules[0].disallowPatterns.map((d) => d.pattern).toList(),
        equals([r'$TARGET_DIR/**']),
      );
    });

    test('allows \$TARGET_DIR in exclude_disallow field', () {
      final yaml = r'''
rules:
  - reason: Valid rule
    target: lib/**
    disallow: "**/src/**"
    exclude_disallow: "$TARGET_DIR/**"
''';

      // Should not throw
      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;
      expect(rules, hasLength(1));
      expect(
        rules[0].excludeDisallowPatterns.map((d) => d.pattern).toList(),
        equals([r'$TARGET_DIR/**']),
      );
    });
  });

  group('\$TARGET_DIR with multiple target patterns', () {
    test('\$TARGET_DIR works correctly with single target pattern', () {
      final yaml = r'''
rules:
  - reason: Test single target
    target: lib/features/auth/**
    disallow: "**/src/**"
    exclude_disallow: "$TARGET_DIR/**"
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;
      expect(rules, hasLength(1));

      // File in lib/features/auth/src can import from same src
      expect(
        rules[0].canImport(
          'lib/features/auth/src/cache.dart',
          Import(uri: 'lib/features/auth/src/utils.dart'),
        ),
        isTrue,
      );

      // File in lib/features/auth can import from its src
      expect(
        rules[0].canImport(
          'lib/features/auth/auth.dart',
          Import(uri: 'lib/features/auth/src/utils.dart'),
        ),
        isTrue,
      );
    });

    test('\$TARGET_DIR works correctly with multiple target patterns', () {
      final yaml = r'''
rules:
  - reason: Test multiple targets
    target:
      - lib/features/auth/**
      - lib/features/profile/**
      - lib/features/settings/**
    disallow: "**/src/**"
    exclude_disallow: "$TARGET_DIR/**"
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;
      expect(rules, hasLength(1));

      // Auth file can import from auth src
      expect(
        rules[0].canImport(
          'lib/features/auth/auth.dart',
          Import(uri: 'lib/features/auth/src/utils.dart'),
        ),
        isTrue,
      );

      // Profile file can import from profile src
      expect(
        rules[0].canImport(
          'lib/features/profile/profile.dart',
          Import(uri: 'lib/features/profile/src/utils.dart'),
        ),
        isTrue,
      );

      // Settings file can import from settings src
      expect(
        rules[0].canImport(
          'lib/features/settings/settings.dart',
          Import(uri: 'lib/features/settings/src/utils.dart'),
        ),
        isTrue,
      );

      // Auth file cannot import from profile src (different module)
      expect(
        rules[0].canImport(
          'lib/features/auth/auth.dart',
          Import(uri: 'lib/features/profile/src/utils.dart'),
        ),
        isFalse,
      );

      // Profile file cannot import from settings src (different module)
      expect(
        rules[0].canImport(
          'lib/features/profile/profile.dart',
          Import(uri: 'lib/features/settings/src/utils.dart'),
        ),
        isFalse,
      );
    });

    test(
      '\$TARGET_DIR is evaluated per matched file, not per target pattern',
      () {
        final yaml = r'''
rules:
  - reason: TARGET_DIR is file-specific
    target:
      - lib/features/auth/**
      - lib/core/**
    disallow: "**"
    exclude_disallow: "$TARGET_DIR/**"
''';

        final rules = ConfigParser().parseRulesFromYaml(yaml).rules;
        expect(rules, hasLength(1));

        // Auth file has TARGET_DIR=lib/features/auth
        expect(
          rules[0].canImport(
            'lib/features/auth/login.dart',
            Import(uri: 'lib/features/auth/models/user.dart'),
          ),
          isTrue,
        );
        expect(
          rules[0].canImport(
            'lib/features/auth/login.dart',
            Import(uri: 'lib/core/entity.dart'),
          ),
          isFalse,
        );

        // Core file has TARGET_DIR=lib/core
        expect(
          rules[0].canImport(
            'lib/core/entity.dart',
            Import(uri: 'lib/core/value.dart'),
          ),
          isTrue,
        );
        expect(
          rules[0].canImport(
            'lib/core/entity.dart',
            Import(uri: 'lib/features/auth/login.dart'),
          ),
          isFalse,
        );
      },
    );
  });

  group('ConfigParser().parseRulesFromYaml - analysis_options.yaml format', () {
    test('parses rules under import_rules section', () {
      final yaml = '''
import_rules:
  rules:
    - reason: Testing
      target: lib/**
      disallow: test/**
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(rules[0].reason, equals('Testing'));
      expect(
        rules[0].targetPatterns.map((t) => t.pattern).toList(),
        equals(['lib/**']),
      );
      expect(
        rules[0].disallowPatterns.map((d) => d.pattern).toList(),
        equals(['test/**']),
      );
    });

    test('parses multiple rules under import_rules section', () {
      final yaml = '''
import_rules:
  rules:
    - reason: First rule
      target: lib/features/**
      disallow: lib/data/**
    - reason: Second rule
      target: lib/core/**
      disallow: package:flutter/**
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(2));
      expect(rules[0].reason, equals('First rule'));
      expect(rules[1].reason, equals('Second rule'));
    });

    test('parses rules with all fields under import_rules section', () {
      final yaml = '''
import_rules:
  rules:
    - reason: Testing all fields
      target: lib/**
      exclude_target: lib/core/**
      disallow: package:flutter/**
      exclude_disallow: package:flutter/material.dart
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(
        rules[0].excludeTargetPatterns.map((t) => t.pattern).toList(),
        equals(['lib/core/**']),
      );
      expect(
        rules[0].excludeDisallowPatterns.map((d) => d.pattern).toList(),
        equals(['package:flutter/material.dart']),
      );
    });

    test('parses rules with \$TARGET_DIR under import_rules section', () {
      final yaml = r'''
import_rules:
  rules:
    - reason: TARGET_DIR test
      target: "**"
      disallow: "**/src/**"
      exclude_disallow: "$TARGET_DIR/**"
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(
        rules[0].excludeDisallowPatterns.map((d) => d.pattern).toList(),
        equals([r'$TARGET_DIR/**']),
      );
    });

    test(
      'parses analysis_options.yaml with other sections alongside import_rules',
      () {
        final yaml = '''
analyzer:
  strong-mode:
    implicit-casts: false

linter:
  rules:
    - avoid_print
    - prefer_const_constructors

import_rules:
  rules:
    - reason: Testing
      target: lib/**
      disallow: test/**
''';

        final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

        expect(rules, hasLength(1));
        expect(
          rules[0].targetPatterns.map((t) => t.pattern).toList(),
          equals(['lib/**']),
        );
        expect(
          rules[0].disallowPatterns.map((d) => d.pattern).toList(),
          equals(['test/**']),
        );
      },
    );

    test(
      'throws when import_rules section exists but rules key is missing',
      () {
        final yaml = '''
import_rules:
  other_config: value
''';

        expect(
          () => ConfigParser().parseRulesFromYaml(yaml),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('rules'),
            ),
          ),
        );
      },
    );
  });

  group('Real-world examples from spec', () {
    test('parses Layer Architecture Enforcement example', () {
      final yaml = '''
rules:
  - reason: Presentation layer should not directly import data layer
    target: lib/presentation/**
    disallow: lib/data/**
    exclude_disallow: lib/data/models/**
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(
        rules[0].canImport(
          'lib/presentation/pages/home.dart',
          Import(uri: 'lib/data/models/user.dart'),
        ),
        isTrue,
      );
      expect(
        rules[0].canImport(
          'lib/presentation/pages/home.dart',
          Import(uri: 'lib/data/repositories/user_repository.dart'),
        ),
        isFalse,
      );
    });

    test('parses src Directory Encapsulation example', () {
      final yaml = r'''
rules:
  - reason: src/ directories are always private to their parent module
    target: "**"
    disallow: "**/src/**"
    exclude_disallow: "$TARGET_DIR/**"
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(
        rules[0].canImport(
          'lib/features/auth/auth.dart',
          Import(uri: 'lib/features/auth/src/utils.dart'),
        ),
        isTrue,
      );
      expect(
        rules[0].canImport(
          'lib/infrastructure/db.dart',
          Import(uri: 'lib/domain/src/entity.dart'),
        ),
        isFalse,
      );
    });

    test('parses Core Domain Independence example', () {
      final yaml = '''
rules:
  - reason: Core domain must remain framework-agnostic
    target: lib/core/**
    disallow:
      - package:flutter/**
      - lib/ui/**
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(
        rules[0].disallowPatterns.map((d) => d.pattern).toList(),
        hasLength(2),
      );
      expect(
        rules[0].canImport(
          'lib/core/entities/user.dart',
          Import(uri: 'package:flutter/material.dart'),
        ),
        isFalse,
      );
    });

    test('parses multiple rules from spec', () {
      final yaml = '''
rules:
  - reason: Presentation layer should not directly import data layer
    target: lib/presentation/**
    disallow: lib/data/**
    exclude_disallow: lib/data/models/**

  - reason: Core domain must remain framework-agnostic
    target: lib/core/**
    disallow:
      - package:flutter/**
      - lib/ui/**

  - reason: Features should not cross-import each other
    target: lib/features/auth/**
    disallow:
      - lib/features/profile/**
      - lib/features/settings/**
      - lib/features/cart/**
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(3));
      expect(
        rules[0].reason,
        equals('Presentation layer should not directly import data layer'),
      );
      expect(
        rules[1].reason,
        equals('Core domain must remain framework-agnostic'),
      );
      expect(
        rules[2].reason,
        equals('Features should not cross-import each other'),
      );
    });
  });

  group('Reason field normalization', () {
    test('single-line reason remains unchanged', () {
      final yaml = '''
rules:
  - reason: This is a simple single-line reason
    target: lib/**
    disallow: test/**
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(rules[0].reason, equals('This is a simple single-line reason'));
    });

    test('literal block scalar (|) with newlines normalized to spaces', () {
      final yaml = '''
rules:
  - reason: |
      This is a multi-line reason
      that spans multiple lines
      using literal block scalar
    target: lib/**
    disallow: test/**
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(
        rules[0].reason,
        equals(
          'This is a multi-line reason that spans multiple lines using literal block scalar',
        ),
      );
    });

    test('literal block scalar with strip chomping (|-) normalized', () {
      final yaml = '''
rules:
  - reason: |-
      First line
      Second line
      Third line
    target: lib/**
    disallow: test/**
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(rules[0].reason, equals('First line Second line Third line'));
    });

    test('folded block scalar (>) with newlines normalized', () {
      final yaml = '''
rules:
  - reason: >
      This folded block scalar
      will have its newlines
      converted to spaces
    target: lib/**
    disallow: test/**
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      // Folded scalar may already convert some newlines, but our normalizer ensures consistency
      expect(
        rules[0].reason,
        equals(
          'This folded block scalar will have its newlines converted to spaces',
        ),
      );
    });

    test('double-quoted with explicit \\n escape sequences normalized', () {
      final yaml = r'''
rules:
  - reason: "First line\nSecond line\nThird line"
    target: lib/**
    disallow: test/**
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(rules[0].reason, equals('First line Second line Third line'));
    });

    test('plain multi-line string normalized', () {
      final yaml = '''
rules:
  - reason: This is a plain string
      that continues on the next line
      and another line
    target: lib/**
    disallow: test/**
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      // Plain style may be pre-processed by YAML, but verify it's normalized
      expect(rules[0].reason, isNot(contains('\n')));
    });

    test('leading and trailing newlines are trimmed', () {
      final yaml = '''
rules:
  - reason: |


      Reason with leading newlines


    target: lib/**
    disallow: test/**
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(rules[0].reason, equals('Reason with leading newlines'));
    });

    test('multiple consecutive newlines preserved as multiple spaces', () {
      final yaml = r'''
rules:
  - reason: "First paragraph\n\n\nSecond paragraph after blank lines"
    target: lib/**
    disallow: test/**
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      // Three newlines become three spaces
      expect(
        rules[0].reason,
        equals('First paragraph   Second paragraph after blank lines'),
      );
    });

    test('consecutive spaces within text are preserved', () {
      final yaml = '''
rules:
  - reason: "Reason with    multiple    spaces    between    words"
    target: lib/**
    disallow: test/**
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(
        rules[0].reason,
        equals('Reason with    multiple    spaces    between    words'),
      );
    });

    test('complex example with mixed whitespace', () {
      final yaml = '''
rules:
  - reason: |
      Presentation layer should not directly import data layer.

      This enforces clean architecture principles by ensuring
      that UI components remain decoupled from data sources.
    target: lib/presentation/**
    disallow: lib/data/**
''';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(
        rules[0].reason,
        equals(
          'Presentation layer should not directly import data layer.  This enforces clean architecture principles by ensuring that UI components remain decoupled from data sources.',
        ),
      );
    });

    test('Windows-style line endings (\\r\\n) normalized', () {
      // Create a string with actual \r\n characters
      final yaml =
          'rules:\n  - reason: "Line one\r\nLine two\r\nLine three"\n    target: lib/**\n    disallow: test/**\n';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(rules[0].reason, equals('Line one Line two Line three'));
    });

    test('old Mac-style line endings (\\r) normalized', () {
      // Create a string with actual \r characters
      final yaml =
          'rules:\n  - reason: "Line one\rLine two\rLine three"\n    target: lib/**\n    disallow: test/**\n';

      final rules = ConfigParser().parseRulesFromYaml(yaml).rules;

      expect(rules, hasLength(1));
      expect(rules[0].reason, equals('Line one Line two Line three'));
    });
  });
}
