import 'dart:io';

import 'test_environment.dart';

void main() {
  final testEnv = TestEnvironment(rootDir: Directory('.testenv'));
  testEnv.setUp();

  final workspace =
      testEnv.createWorkspace(
        name: 'workspace',
        sdkVersionConstraint: '^3.10.0',
      )..createFiles({
        'analysis_options.yaml': '''
plugins:
  import_rules:
    path: ../../
''',
        'import_rules.yaml': '''
rules:
  - target: "**"
    disallow: "**/src/**"
    reason: Implementations should not be imported directly.
''',
      });

  workspace.createPackage(name: 'test_project').createFiles({
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
  });

  // if (!workspace.pubGet()) {
  //   throw Exception('Failed to pub get package');
  // }
  // final result = workspace.analyze();
  // print(result);
}
