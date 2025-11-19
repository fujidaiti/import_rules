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

    //     final templateProject = Directory(p.join(rootDir.path, 'template'));
    //     templateProject.createSync();

    //     final pubspecYamlContent = StringBuffer('''
    // name: test_project
    // version: 0.0.0

    // environment:
    //   sdk: ^3.10.0
    // ''');

    //     final pubspecYamlFile = File(p.join(templateProject.path, 'pubspec.yaml'));
    //     pubspecYamlFile.writeAsStringSync(pubspecYamlContent.toString());
    //     _dartCommand.pubGet(templateProject);
    //     final dartToolDir = Directory(p.join(templateProject.path, '.dart_tool'));
    //     assert(dartToolDir.existsSync());

    //     _sharedAssets = [pubspecYamlFile, dartToolDir];
  }

  void tearDown() {
    assert(_isSetUp, 'Test environment not set up');
    assert(!_isTornDown, 'Test environment already torn down');
    _isTornDown = true;

    if (rootDir.existsSync()) {
      rootDir.deleteSync(recursive: true);
    }
  }

  Directory createPackage({
    required String uniqueName,
    required Map<String, Object> sources,
  }) {
    final projectDir = Directory(p.join(rootDir.path, uniqueName));
    assert(
      !projectDir.existsSync(),
      'Test project "$uniqueName" already exists',
    );
    projectDir.createSync();

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

    // Recursively create subdirectories and source files.
    createSourceFiles(projectDir, sources);

    return projectDir;
  }
}

class DartPackage {
  DartPackage._({
    required this.name,
    required this.root,
    required this.environment,
  }) : pubspec = File(p.join(root.path, 'pubspec.yaml')),
       pubspecLock = File(p.join(root.path, 'pubspec.lock')),
       dartTool = Directory(p.join(root.path, '.dart_tool'));

  final String name;
  final Directory root;
  final TestEnvironment environment;
  final File pubspec;
  final File pubspecLock;
  final Directory dartTool;

  void pubGet() {
    environment._dartCommand.pubGet(root);
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

  void pubGet(Directory package) {
    final result = Process.runSync(_dartExecutable, [
      'pub',
      'get',
    ], workingDirectory: package.path);
    if (result.exitCode != 0) {
      throw Exception('dart pub get failed: ${result.stderr}');
    }
  }

  AnalyzerOutput analyze(Directory package) {
    final result = Process.runSync(_dartExecutable, [
      'analyze',
    ], workingDirectory: package.path);
    return AnalyzerOutput.parse(result.stdout.toString());
  }
}
