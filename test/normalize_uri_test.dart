import 'dart:io';

import 'package:import_rules/main.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('normalizeUri', () {
    late String tempDir;
    late String packageRoot;

    setUp(() {
      // Create a temporary directory structure for testing
      tempDir = Directory.systemTemp.createTempSync('normalize_uri_test').path;
      packageRoot = p.join(tempDir, 'my_project');
      Directory(packageRoot).createSync();
      Directory(p.join(packageRoot, 'lib')).createSync();
      Directory(p.join(packageRoot, 'test')).createSync();
    });

    tearDown(() {
      // Clean up temp directory
      Directory(tempDir).deleteSync(recursive: true);
    });

    group('file:// URI normalization', () {
      test('normalizes lib/ file to relative path', () {
        final filePath = p.join(packageRoot, 'lib', 'main.dart');
        final uri = Uri.file(filePath);

        final result = normalizeUri(uri, packageRoot, 'my_project');

        expect(result, equals(p.join('lib', 'main.dart')));
      });

      test('normalizes nested lib/ file to relative path', () {
        final filePath = p.join(packageRoot, 'lib', 'src', 'config.dart');
        final uri = Uri.file(filePath);

        final result = normalizeUri(uri, packageRoot, 'my_project');

        expect(result, equals(p.join('lib', 'src', 'config.dart')));
      });

      test('normalizes test/ file to relative path', () {
        final filePath = p.join(
          packageRoot,
          'test',
          'unit',
          'config_test.dart',
        );
        final uri = Uri.file(filePath);

        final result = normalizeUri(uri, packageRoot, 'my_project');

        expect(result, equals(p.join('test', 'unit', 'config_test.dart')));
      });

      test('normalizes root-level file to relative path', () {
        final filePath = p.join(packageRoot, 'README.md');
        final uri = Uri.file(filePath);

        final result = normalizeUri(uri, packageRoot, 'my_project');

        expect(result, equals('README.md'));
      });

      test('handles deeply nested paths', () {
        final filePath = p.join(
          packageRoot,
          'lib',
          'features',
          'auth',
          'src',
          'utils.dart',
        );
        final uri = Uri.file(filePath);

        final result = normalizeUri(uri, packageRoot, 'my_project');

        expect(
          result,
          equals(p.join('lib', 'features', 'auth', 'src', 'utils.dart')),
        );
      });
    });

    group('package: URI normalization for internal packages', () {
      test('normalizes simple package URI to lib/ path', () {
        final uri = Uri.parse('package:my_project/main.dart');

        final result = normalizeUri(uri, packageRoot, 'my_project');

        expect(result, equals('lib/main.dart'));
      });

      test('normalizes nested package URI to lib/ path', () {
        final uri = Uri.parse('package:my_project/src/config.dart');

        final result = normalizeUri(uri, packageRoot, 'my_project');

        expect(result, equals('lib/src/config.dart'));
      });

      test('normalizes deeply nested package URI', () {
        final uri = Uri.parse(
          'package:my_project/features/auth/src/utils.dart',
        );

        final result = normalizeUri(uri, packageRoot, 'my_project');

        expect(result, equals('lib/features/auth/src/utils.dart'));
      });

      test('handles package URIs with multiple slashes', () {
        final uri = Uri.parse('package:my_project/a/b/c/d/file.dart');

        final result = normalizeUri(uri, packageRoot, 'my_project');

        expect(result, equals('lib/a/b/c/d/file.dart'));
      });
    });

    group('package: URI normalization for external packages', () {
      test('keeps external package URI unchanged', () {
        final uri = Uri.parse('package:flutter/material.dart');

        final result = normalizeUri(uri, packageRoot, 'my_project');

        expect(result, equals('package:flutter/material.dart'));
      });

      test('keeps nested external package URI unchanged', () {
        final uri = Uri.parse('package:flutter/widgets/framework.dart');

        final result = normalizeUri(uri, packageRoot, 'my_project');

        expect(result, equals('package:flutter/widgets/framework.dart'));
      });

      test('keeps dart: core library unchanged', () {
        final uri = Uri.parse('dart:core');

        final result = normalizeUri(uri, packageRoot, 'my_project');

        expect(result, equals('dart:core'));
      });

      test('keeps dart: async library unchanged', () {
        final uri = Uri.parse('dart:async');

        final result = normalizeUri(uri, packageRoot, 'my_project');

        expect(result, equals('dart:async'));
      });

      test('distinguishes between similar package names', () {
        // Package name: my_project
        // External package: my_project_utils (should not be normalized)
        final uri = Uri.parse('package:my_project_utils/helper.dart');

        final result = normalizeUri(uri, packageRoot, 'my_project');

        expect(result, equals('package:my_project_utils/helper.dart'));
      });
    });

    group('edge cases', () {
      test('handles package name with underscores', () {
        final uri = Uri.parse('package:my_awesome_project/src/file.dart');

        final result = normalizeUri(uri, packageRoot, 'my_awesome_project');

        expect(result, equals('lib/src/file.dart'));
      });

      test('handles single-segment file paths', () {
        final uri = Uri.parse('package:my_project/single.dart');

        final result = normalizeUri(uri, packageRoot, 'my_project');

        expect(result, equals('lib/single.dart'));
      });

      test('returns unknown scheme URIs unchanged', () {
        final uri = Uri.parse('https://example.com/file.dart');

        final result = normalizeUri(uri, packageRoot, 'my_project');

        expect(result, equals('https://example.com/file.dart'));
      });

      test('handles empty path segment', () {
        // This shouldn't happen in practice, but testing robustness
        final uri = Uri.parse('package:my_project/');

        final result = normalizeUri(uri, packageRoot, 'my_project');

        expect(result, equals('lib/'));
      });
    });

    group('consistency checks', () {
      test('file:// and package: URIs normalize to same path', () {
        final filePath = p.join(packageRoot, 'lib', 'src', 'config.dart');
        final fileUri = Uri.file(filePath);
        final packageUri = Uri.parse('package:my_project/src/config.dart');

        final fileResult = normalizeUri(fileUri, packageRoot, 'my_project');
        final packageResult = normalizeUri(
          packageUri,
          packageRoot,
          'my_project',
        );

        expect(fileResult, equals(p.join('lib', 'src', 'config.dart')));
        expect(packageResult, equals('lib/src/config.dart'));
        // Note: Path separators may differ (/ vs \), but logical path is same
        expect(p.normalize(fileResult), equals(p.normalize(packageResult)));
      });
    });
  });
}
