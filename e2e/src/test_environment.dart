import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'analyzer_output.dart';
import 'io_extension.dart';

class TestEnvironment {
  TestEnvironment({required this.root});

  final Directory root;

  var _isSetUp = false;
  var _isTornDown = false;

  void setUp() {
    assert(!_isSetUp, 'Test environment already set up');
    _isSetUp = true;

    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
    root.createSync();
  }

  void tearDown() {
    assert(_isSetUp, 'Test environment not set up');
    assert(!_isTornDown, 'Test environment already torn down');
    _isTornDown = true;

    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  }

  DartPackage createPackage({
    required String name,
    Directory? root,
    required String sdkVersionConstraint,
    String? resolution,
    Map<String, String> dependencies = const {},
  }) {
    final packageRoot = root ?? this.root.childDirectory(name);
    assert(
      !packageRoot.existsSync(),
      '${packageRoot.path} already exists in the test environment',
    );
    packageRoot.createSync(recursive: true);

    _PubspecYamlBuffer()
      ..name = name
      ..version = '0.0.0'
      ..sdkVersionConstraint = sdkVersionConstraint
      ..resolution = resolution
      ..dependencies = dependencies
      ..flushTo(File(p.join(packageRoot.path, 'pubspec.yaml')));

    return DartPackage._(name: name, root: packageRoot, environment: this);
  }

  DartWorkspace createWorkspace({
    required String name,
    required String sdkVersionConstraint,
  }) {
    final workspaceRoot = Directory(p.join(root.path, name));
    if (workspaceRoot.existsSync()) {
      throw AssertionError(
        'Workspace "$name" already exists in test environment',
      );
    }
    workspaceRoot.createSync();

    _PubspecYamlBuffer()
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

  void pubGet() {
    final result = Process.runSync('dart', [
      'pub',
      'get',
    ], workingDirectory: root.absolute.path);
    if (result.exitCode != 0) {
      throw Exception(
        'Failed to pub get package ${root.path}: ${result.stderr}',
      );
    }
  }

  AnalyzerOutput analyze() {
    final result = Process.runSync('dart', [
      'analyze',
    ], workingDirectory: root.absolute.path);
    return AnalyzerOutput.parse(result.stdout.toString());
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
      root: packages.childDirectory(name),
      sdkVersionConstraint: sdkVersionConstraint,
      resolution: 'workspace',
    );

    final relativePackagePath = p.relative(
      package.root.absolute.path,
      from: root.absolute.path,
    );

    _PubspecYamlBuffer.open(pubspec)
      ..workspacePackages.add(relativePackagePath)
      ..flushTo(pubspec);

    return package;
  }
}

class _PubspecYamlBuffer {
  _PubspecYamlBuffer();

  factory _PubspecYamlBuffer.open(File file) {
    final yaml = loadYaml(file.readAsStringSync());
    if (yaml is! Map) {
      throw StateError('Invalid pubspec.yaml: ${file.absolute.path}');
    }

    final buffer = _PubspecYamlBuffer();
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
    final buffer = StringBuffer();

    if (name != null) {
      buffer.writeln('name: $name');
    }
    if (version != null) {
      buffer.writeln('version: $version');
    }
    if (sdkVersionConstraint != null) {
      buffer.writeln('environment:');
      buffer.writeln('  sdk: $sdkVersionConstraint');
    }
    if (resolution != null) {
      buffer.writeln('resolution: $resolution');
    }
    if (dependencies.isNotEmpty) {
      buffer.writeln('dependencies:');
      for (final entry in dependencies.entries) {
        buffer.writeln('  ${entry.key}: ${entry.value}');
      }
    }
    if (devDependencies.isNotEmpty) {
      buffer.writeln('dev_dependencies:');
      for (final entry in devDependencies.entries) {
        buffer.writeln('  ${entry.key}: ${entry.value}');
      }
    }
    if (workspacePackages.isNotEmpty) {
      buffer.writeln('workspace:');
      for (final package in workspacePackages) {
        buffer.writeln('  - $package');
      }
    }

    file.writeAsStringSync(buffer.toString(), mode: FileMode.write);
  }
}
