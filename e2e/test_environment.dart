import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/analyzer_output.dart';

class TestEnvironment {
  TestEnvironment({required this.rootDir});

  final Directory rootDir;

  var _isSetUp = false;
  var _isTornDown = false;
  late final _DartCommand _dartCommand;

  void setUp() {
    assert(!_isSetUp, 'Test environment already set up');
    _isSetUp = true;
    _dartCommand = _DartCommand.prepare();

    if (rootDir.existsSync()) {
      rootDir.deleteSync(recursive: true);
    }
    rootDir.createSync();
  }

  void tearDown() {
    assert(_isSetUp, 'Test environment not set up');
    assert(!_isTornDown, 'Test environment already torn down');
    _isTornDown = true;

    if (rootDir.existsSync()) {
      rootDir.deleteSync(recursive: true);
    }
  }

  DartPackage createPackage({
    required String name,
    required String sdkVersionConstraint,
    Map<String, String> dependencies = const {},
    required Map<String, Object> sources,
  }) {
    final projectDir = Directory(p.join(rootDir.path, name));
    assert(
      !projectDir.existsSync(),
      'Package "$name" already exists in test environment',
    );
    projectDir.createSync();

    // Create pubspec.yaml
    final pubspecYaml = StringBuffer('''
name: $name
version: 0.0.0

environment:
  sdk: $sdkVersionConstraint
''');
    if (dependencies.isNotEmpty) {
      pubspecYaml.write('dependencies:\n');
      for (final entry in dependencies.entries) {
        pubspecYaml.write('  ${entry.key}: ${entry.value}\n');
      }
    }
    File(
      p.join(projectDir.path, 'pubspec.yaml'),
    ).writeAsStringSync(pubspecYaml.toString());

    // Create analysis_options.yaml
    final analysisOptionsYaml = StringBuffer('''
plugins:
  import_rules:
    path: ${Directory.current.absolute.path}
''');
    File(
      p.join(projectDir.path, 'analysis_options.yaml'),
    ).writeAsStringSync(analysisOptionsYaml.toString());

    // Recursively create subdirectories and source files.
    void createSourceFiles(Directory parentDir, Map<String, Object> sources) {
      for (final entry in sources.entries) {
        if (entry.value case final String content) {
          File(p.join(parentDir.path, entry.key))
            ..createSync(exclusive: true)
            ..writeAsStringSync(content);
        } else if (entry.value case final Map<String, Object> subSources) {
          final subDir = Directory(p.join(parentDir.path, entry.key))
            ..createSync();
          createSourceFiles(subDir, subSources);
        } else {
          assert(
            false,
            'Invalid source type ${entry.value.runtimeType} '
            'for ${parentDir.path}/${entry.key}',
          );
        }
      }
    }

    createSourceFiles(projectDir, sources);

    return DartPackage._(name: name, root: projectDir, environment: this);
  }
}

class DartPackage {
  DartPackage._({
    required this.name,
    required this.root,
    required this.environment,
  }) : pubspec = File(p.join(root.path, 'pubspec.yaml')),
       pubspecLock = File(p.join(root.path, 'pubspec.lock')),
       analysisOptions = File(p.join(root.path, 'analysis_options.yaml')),
       dartTool = Directory(p.join(root.path, '.dart_tool'));

  final String name;
  final Directory root;
  final TestEnvironment environment;
  final File pubspec;
  final File pubspecLock;
  final File analysisOptions;
  final Directory dartTool;

  bool pubGet() {
    return environment._dartCommand.pubGet(root);
  }

  AnalyzerOutput analyze() {
    return environment._dartCommand.analyze(root);
  }
}

class _DartCommand {
  factory _DartCommand.prepare() {
    final fvmDir = Directory('.fvm');
    if (fvmDir.existsSync()) {
      return _DartCommand._(
        p.join(
          fvmDir.path,
          'flutter_sdk',
          'bin',
          'cache',
          'dart-sdk',
          'bin',
          'dart',
        ),
      );
    }

    return _DartCommand._('dart');
  }

  _DartCommand._(this._dartExecutable);

  final String _dartExecutable;

  bool pubGet(Directory package) {
    final result = Process.runSync(_dartExecutable, [
      'pub',
      'get',
    ], workingDirectory: package.path);
    return result.exitCode == 0;
  }

  AnalyzerOutput analyze(Directory package) {
    final result = Process.runSync(_dartExecutable, [
      'analyze',
    ], workingDirectory: package.path);
    return AnalyzerOutput.parse(result.stdout.toString());
  }
}
