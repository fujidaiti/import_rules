import 'dart:io';

import 'test_environment.dart';

void main() {
  final testEnv = TestEnvironment(
    rootDir: Directory('.testenv'),
    sharedDependencies: {'path': '^1.9.0'},
  );

  testEnv.setUp();
  final project = testEnv.createTestProject(
    uniqueName: 'test_project',
    sources: {
      'analysis_options.yaml': '''
plugins:
  import_rules:
    path: ../../

import_rules:
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

  final result = testEnv.analyze(project);
  print(result);
}
