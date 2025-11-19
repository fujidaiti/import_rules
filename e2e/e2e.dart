import 'dart:io';

import 'test_environment.dart';

void main() {
  final testEnv = TestEnvironment(rootDir: Directory('.testenv'));

  testEnv.setUp();
  final package = testEnv.createPackage(
    name: 'test_project',
    sdkVersionConstraint: '^3.10.0',
    sources: {
      'import_rules.yaml': '''
rules:
  - target: "**"
    disallow: "**/src/**"
    reason: Implementations should not be imported directly.
''',
      'lib': {
        'main.dart': '''
import 'package:test_project/src/calculator.dart';

void main() {
  print(Calculator().add(0, 2));
}
        ''',
        'src': {
          'calculator.dart': '''
class Calculator {
  int add(int a, int b) {
    return a + b;
  }
}
        ''',
        },
      },
    },
  );

  if (!package.pubGet()) {
    throw Exception('Failed to pub get package');
  }
  final result = package.analyze();
  print(result);
}
