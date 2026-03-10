import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';
import 'package:test/test.dart';

void main() {
  late JsonSchema schema;

  setUpAll(() {
    final file = File('import_rules.schema.json');
    final schemaMap =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    schema = JsonSchema.create(schemaMap);
  });

  ValidationResults validate(Map<String, dynamic> data) =>
      schema.validate(data);

  group('Valid configurations', () {
    test('minimal rule', () {
      final result = validate({
        'rules': [
          {
            'reason': 'No test imports in lib',
            'target': 'lib/**',
            'disallow': 'test/**',
          },
        ],
      });
      expect(result.isValid, isTrue);
    });

    test('rule with array targets and disallows', () {
      final result = validate({
        'rules': [
          {
            'reason': 'Isolation',
            'target': ['lib/a/**', 'lib/b/**'],
            'disallow': ['lib/c/**', 'lib/d/**'],
          },
        ],
      });
      expect(result.isValid, isTrue);
    });

    test('rule with all optional fields', () {
      final result = validate({
        'rules': [
          {
            'reason': 'Complex rule',
            'target': 'lib/**',
            'exclude_target': 'lib/src/**',
            'disallow': 'test/**',
            'exclude_disallow': 'test/helpers/**',
            'severity': 'warning',
          },
        ],
      });
      expect(result.isValid, isTrue);
    });

    test('multiple rules', () {
      final result = validate({
        'rules': [
          {'reason': 'Rule 1', 'target': 'lib/**', 'disallow': 'test/**'},
          {'reason': 'Rule 2', 'target': 'test/**', 'disallow': 'lib/src/**'},
        ],
      });
      expect(result.isValid, isTrue);
    });

    test('global severity field', () {
      final result = validate({
        'rules': [
          {'reason': 'A rule', 'target': 'lib/**', 'disallow': 'test/**'},
        ],
        'severity': 'error',
      });
      expect(result.isValid, isTrue);
    });

    test(r'$TARGET_DIR in disallow is allowed', () {
      final result = validate({
        'rules': [
          {
            'reason': 'Only import from own dir',
            'target': 'lib/src/**',
            'disallow': r'$TARGET_DIR/**',
          },
        ],
      });
      expect(result.isValid, isTrue);
    });

    test(r'$TARGET_DIR in exclude_disallow is allowed', () {
      final result = validate({
        'rules': [
          {
            'reason': 'Except own dir',
            'target': 'lib/src/**',
            'disallow': 'lib/**',
            'exclude_disallow': r'$TARGET_DIR/**',
          },
        ],
      });
      expect(result.isValid, isTrue);
    });

    test('package: prefix in disallow is allowed', () {
      final result = validate({
        'rules': [
          {
            'reason': 'No flutter',
            'target': 'lib/**',
            'disallow': 'package:flutter/material.dart',
          },
        ],
      });
      expect(result.isValid, isTrue);
    });
  });

  group('Invalid configurations - targetPattern regex', () {
    test('target starting with package: is rejected', () {
      final result = validate({
        'rules': [
          {
            'reason': 'Bad target',
            'target': 'package:foo/bar.dart',
            'disallow': 'test/**',
          },
        ],
      });
      expect(result.isValid, isFalse);
    });

    test(r'target containing $TARGET_DIR is rejected', () {
      final result = validate({
        'rules': [
          {
            'reason': 'Bad target',
            'target': r'lib/$TARGET_DIR/foo.dart',
            'disallow': 'test/**',
          },
        ],
      });
      expect(result.isValid, isFalse);
    });

    test('exclude_target starting with package: is rejected', () {
      final result = validate({
        'rules': [
          {
            'reason': 'Bad exclude_target',
            'target': 'lib/**',
            'exclude_target': 'package:foo/bar.dart',
            'disallow': 'test/**',
          },
        ],
      });
      expect(result.isValid, isFalse);
    });

    test(r'exclude_target containing $TARGET_DIR is rejected', () {
      final result = validate({
        'rules': [
          {
            'reason': 'Bad exclude_target',
            'target': 'lib/**',
            'exclude_target': r'$TARGET_DIR/foo.dart',
            'disallow': 'test/**',
          },
        ],
      });
      expect(result.isValid, isFalse);
    });

    test('empty string target is rejected', () {
      final result = validate({
        'rules': [
          {'reason': 'Empty target', 'target': '', 'disallow': 'test/**'},
        ],
      });
      expect(result.isValid, isFalse);
    });
  });

  group('Invalid configurations - structural', () {
    test('missing rules key', () {
      final result = validate({'severity': 'error'});
      expect(result.isValid, isFalse);
    });

    test('missing reason field', () {
      final result = validate({
        'rules': [
          {'target': 'lib/**', 'disallow': 'test/**'},
        ],
      });
      expect(result.isValid, isFalse);
    });

    test('missing target field', () {
      final result = validate({
        'rules': [
          {'reason': 'No target', 'disallow': 'test/**'},
        ],
      });
      expect(result.isValid, isFalse);
    });

    test('missing disallow field', () {
      final result = validate({
        'rules': [
          {'reason': 'No disallow', 'target': 'lib/**'},
        ],
      });
      expect(result.isValid, isFalse);
    });

    test('invalid severity value', () {
      final result = validate({
        'rules': [
          {
            'reason': 'Bad severity',
            'target': 'lib/**',
            'disallow': 'test/**',
            'severity': 'fatal',
          },
        ],
      });
      expect(result.isValid, isFalse);
    });

    test('unknown property in rule object', () {
      final result = validate({
        'rules': [
          {
            'reason': 'Extra prop',
            'target': 'lib/**',
            'disallow': 'test/**',
            'unknown_field': 'value',
          },
        ],
      });
      expect(result.isValid, isFalse);
    });

    test('unknown property at root level', () {
      final result = validate({
        'rules': [
          {'reason': 'A rule', 'target': 'lib/**', 'disallow': 'test/**'},
        ],
        'unknown_root': 'value',
      });
      expect(result.isValid, isFalse);
    });

    test('rules is not an array', () {
      final result = validate({'rules': 'not an array'});
      expect(result.isValid, isFalse);
    });

    test('reason is empty string', () {
      final result = validate({
        'rules': [
          {'reason': '', 'target': 'lib/**', 'disallow': 'test/**'},
        ],
      });
      expect(result.isValid, isFalse);
    });

    test('disallow is empty string', () {
      final result = validate({
        'rules': [
          {'reason': 'Empty disallow', 'target': 'lib/**', 'disallow': ''},
        ],
      });
      expect(result.isValid, isFalse);
    });
  });
}
