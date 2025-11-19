import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

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
    Directory? root,
    required String sdkVersionConstraint,
    String? resolution,
    Map<String, String> dependencies = const {},
  }) {
    final effectiveRoot = root ?? Directory(p.join(rootDir.path, name));
    assert(
      !effectiveRoot.existsSync(),
      'Package "$name" already exists in test environment',
    );
    effectiveRoot.createSync();

    PubspecYamlBuffer()
      ..name = name
      ..version = '0.0.0'
      ..sdkVersionConstraint = sdkVersionConstraint
      ..resolution = resolution
      ..dependencies = dependencies
      ..flushTo(File(p.join(effectiveRoot.path, 'pubspec.yaml')));

    return DartPackage._(name: name, root: effectiveRoot, environment: this);
  }

  DartWorkspace createWorkspace({
    required String name,
    required String sdkVersionConstraint,
  }) {
    final workspaceRoot = Directory(p.join(rootDir.path, name));
    if (workspaceRoot.existsSync()) {
      throw AssertionError(
        'Workspace "$name" already exists in test environment',
      );
    }
    workspaceRoot.createSync();

    PubspecYamlBuffer()
      ..name = name
      ..version = '0.0.0'
      ..sdkVersionConstraint = sdkVersionConstraint
      ..flushTo(File(p.join(workspaceRoot.path, 'pubspec.yaml')));

    return DartWorkspace._(
      name: name,
      root: workspaceRoot,
      sdkVersionConstraint: sdkVersionConstraint,
      environment: this,
    );
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

  File createFile(String relativePath, String content) {
    return File(p.join(root.path, relativePath))
      ..createSync(recursive: true, exclusive: true)
      ..writeAsStringSync(content);
  }

  void createFiles(Map<String, Object> fileTree) {
    void visitor(Directory parentDir, Map<String, Object> fileTree) {
      for (final entry in fileTree.entries) {
        if (entry.value case final String content) {
          File(p.join(parentDir.path, entry.key))
            ..createSync(exclusive: true)
            ..writeAsStringSync(content);
        } else if (entry.value case final Map<String, Object> subSources) {
          final subDir = Directory(p.join(parentDir.path, entry.key))
            ..createSync();
          visitor(subDir, subSources);
        } else {
          throw AssertionError(
            'Invalid entry type ${entry.value.runtimeType} '
            'for ${parentDir.path}/${entry.key}',
          );
        }
      }
    }

    // Recursively create subdirectories and files.
    visitor(root, fileTree);
  }

  bool pubGet() {
    return environment._dartCommand.pubGet(root);
  }

  AnalyzerOutput analyze() {
    return environment._dartCommand.analyze(root);
  }
}

class DartWorkspace extends DartPackage {
  DartWorkspace._({
    required super.name,
    required super.root,
    required super.environment,
    required this.sdkVersionConstraint,
  }) : packages = Directory(p.join(root.path, 'packages')),
       super._();

  final String sdkVersionConstraint;
  final Directory packages;

  DartPackage createPackage({
    required String name,
    Map<String, String> dependencies = const {},
  }) {
    if (!packages.existsSync()) {
      packages.createSync();
    }
    final package = environment.createPackage(
      name: name,
      root: Directory(p.join(packages.path, name)),
      sdkVersionConstraint: sdkVersionConstraint,
      resolution: 'workspace',
    );

    final relativePackagePath = p.relative(
      package.root.absolute.path,
      from: root.absolute.path,
    );

    PubspecYamlBuffer.open(pubspec)
      ..workspacePackages.add(relativePackagePath)
      ..flushTo(pubspec);

    return package;
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

class PubspecYamlBuffer {
  PubspecYamlBuffer();

  factory PubspecYamlBuffer.open(File file) {
    final yaml = loadYaml(file.readAsStringSync());
    if (yaml is! Map) {
      throw StateError('Invalid pubspec.yaml: ${file.absolute.path}');
    }

    final buffer = PubspecYamlBuffer();
    buffer.name = yaml['name'];
    buffer.version = yaml['version'];
    buffer.sdkVersionConstraint = yaml['environment']?['sdk'];
    buffer.resolution = yaml['resolution'];

    if (yaml['dependencies'] case final Map dependencies) {
      for (final entry in dependencies.entries) {
        buffer.dependencies[entry.key] = entry.value;
      }
    }

    if (yaml['dev_dependencies'] case final Map devDependencies) {
      for (final entry in devDependencies.entries) {
        buffer.devDependencies[entry.key] = entry.value;
      }
    }

    if (yaml['workspace'] case final List workspace) {
      buffer.workspacePackages = [...workspace.cast<String>()];
    }

    return buffer;
  }

  String? name;
  String? version;
  String? sdkVersionConstraint;
  String? resolution;
  Map<String, String> dependencies = {};
  Map<String, String> devDependencies = {};
  List<String> workspacePackages = [];

  void flushTo(File file) {
    final pubspecBuffer = StringBuffer();

    if (name != null) {
      pubspecBuffer.writeln('name: $name');
    }
    if (version != null) {
      pubspecBuffer.writeln('version: $version');
    }
    if (sdkVersionConstraint != null) {
      pubspecBuffer.writeln('environment:');
      pubspecBuffer.writeln('  sdk: $sdkVersionConstraint');
    }
    if (resolution != null) {
      pubspecBuffer.writeln('resolution: $resolution');
    }
    if (dependencies.isNotEmpty) {
      pubspecBuffer.writeln('dependencies:');
      for (final entry in dependencies.entries) {
        pubspecBuffer.writeln('  ${entry.key}: ${entry.value}');
      }
    }
    if (devDependencies.isNotEmpty) {
      pubspecBuffer.writeln('dev_dependencies:');
      for (final entry in devDependencies.entries) {
        pubspecBuffer.writeln('  ${entry.key}: ${entry.value}');
      }
    }
    if (workspacePackages.isNotEmpty) {
      pubspecBuffer.writeln('workspace:');
      for (final package in workspacePackages) {
        pubspecBuffer.writeln('  - $package');
      }
    }

    file.writeAsStringSync(pubspecBuffer.toString(), mode: FileMode.write);
  }
}
