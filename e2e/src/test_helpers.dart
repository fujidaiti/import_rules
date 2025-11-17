import 'dart:io';
import 'package:path/path.dart' as p;

import 'analyzer_output.dart';

/// Copies the test project template to a new location
String copyTestProject(String src, String destRoot, String name) {
  final dest = p.join(destRoot, 'test_project_$name');
  _copyDirectory(
    Directory(src),
    Directory(dest),
    excludeDirs: {'.dart_tool', 'build'},
  );
  return dest;
}

void _copyDirectory(
  Directory src,
  Directory dest, {
  Set<String> excludeDirs = const {},
}) {
  dest.createSync(recursive: true);
  for (final entity in src.listSync()) {
    final name = p.basename(entity.path);
    if (excludeDirs.contains(name)) continue;

    if (entity is File) {
      entity.copySync(p.join(dest.path, name));
    } else if (entity is Directory) {
      _copyDirectory(
        entity,
        Directory(p.join(dest.path, name)),
        excludeDirs: excludeDirs,
      );
    }
  }
}

/// Generates import_rules.yaml in the specified project
void generateImportRules(String projectPath, String yamlContent) {
  final rulesFile = File(p.join(projectPath, 'import_rules.yaml'));
  rulesFile.writeAsStringSync(yamlContent);
}

/// Runs dart pub get in the specified project
void runDartPubGet(String projectPath) {
  final result = Process.runSync('fvm', [
    'dart',
    'pub',
    'get',
  ], workingDirectory: projectPath);
  if (result.exitCode != 0) {
    throw Exception('dart pub get failed: ${result.stderr}');
  }
}

/// Runs dart analyze on a specific file and returns parsed output
AnalyzerOutput runDartAnalyze(String projectPath, String targetFile) {
  final result = Process.runSync('fvm', [
    'dart',
    'analyze',
    targetFile,
  ], workingDirectory: projectPath);
  return AnalyzerOutput.parse(result.stdout.toString());
}
