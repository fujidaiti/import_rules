import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/workspace/workspace.dart';
import 'package:import_rules/src/config.dart';
import 'package:yaml/yaml.dart';

import 'import_rule.dart';
import 'logger.dart';

/// Extracts the package name from pubspec.yaml in the given package.
String? _getPackageName(WorkspacePackage package) {
  final pubspecFile = package.root.getChild('pubspec.yaml');
  if (pubspecFile is! File || !pubspecFile.exists) {
    return null;
  }

  try {
    final content = pubspecFile.readAsStringSync();
    final yaml = loadYaml(content);
    if (yaml is Map && yaml['name'] is String) {
      return yaml['name'] as String;
    }
  } catch (_) {
    return null;
  }

  return null;
}

/// Normalizes a disallow pattern to use relative paths from the package root.
///
/// This makes patterns format-agnostic, allowing a single pattern like `lib/main.dart`
/// to match both `import "lib/main.dart"` and `import "package:my_pkg/main.dart"`.
///
/// Normalization rules:
/// - `package:<current_package>/foo.dart` → `lib/foo.dart`
/// - `dart:*` → unchanged (standard library)
/// - `package:<other_package>/**` → unchanged (external package)
/// - `lib/foo.dart` → unchanged (already normalized)
///
/// If packageName is null, patterns are returned unchanged.
String _normalizeDisallowPattern(String pattern, String? packageName) {
  // If no package name, cannot normalize
  if (packageName == null) {
    return pattern;
  }

  // Keep dart:* and external package:* as-is
  if (pattern.startsWith('dart:')) {
    return pattern;
  }

  // Normalize package:<current_package>/foo.dart → lib/foo.dart
  final packagePrefix = 'package:$packageName/';
  if (pattern.startsWith(packagePrefix)) {
    final pathAfterPackage = pattern.substring(packagePrefix.length);
    return 'lib/$pathAfterPackage';
  }

  // Keep external packages (package:other/**) and relative paths as-is
  return pattern;
}

class ConfigParser {
  ConfigParser([this.logger]);

  final Logger? logger;

  Config loadConfigurationFor(WorkspacePackage package) {
    const searchPaths = ['import_rules.yaml', 'analysis_options.yaml'];

    // Get package name from pubspec.yaml
    final packageName = _getPackageName(package);
    if (packageName == null) {
      logger?.warning(
        'Could not determine package name from pubspec.yaml. Pattern normalization will be disabled.',
      );
    }

    for (final searchPath in searchPaths) {
      logger?.info('Searching for configuration in $searchPath');
      final file = package.root.getChild(searchPath);
      if (file is! File || !file.exists) continue;
      final config = tryParseRulesFromYaml(
        file.readAsStringSync(),
        packageName,
      );
      if (config != null) {
        for (final rule in config.rules) {
          logger?.info('Rule loaded:');
          logger?.info('  name: ${rule.name}');
          logger?.info('  reason: ${rule.reason}');
          logger?.info(
            '  target: ${rule.targetPatterns.map((t) => t.pattern).toList()}',
          );
          logger?.info(
            '  disallow: ${rule.disallowPatterns.map((d) => d.pattern).toList()}',
          );
          logger?.info(
            '  exclude_target: ${rule.excludeTargetPatterns.map((t) => t.pattern).toList()}',
          );
          logger?.info(
            '  exclude_disallow: ${rule.excludeDisallowPatterns.map((d) => d.pattern).toList()}',
          );
        }
        return config;
      }
    }

    return const Config.empty();
  }

  Config? tryParseRulesFromYaml(String yamlContent, String? packageName) {
    try {
      return parseRulesFromYaml(yamlContent, packageName);
    } on FormatException catch (error, stackTrace) {
      logger?.severe(
        'Error parsing rules from YAML: $error',
        error,
        stackTrace,
      );
      return null;
    }
  }

  /// Parses import rules from a YAML string.
  ///
  /// The YAML should follow one of these structures:
  ///
  /// For import_rules.yaml:
  /// ```yaml
  /// rules:
  ///   - name: Rule name (optional)
  ///     reason: Why this rule exists (required)
  ///     target: pattern (required, can be string or array)
  ///     exclude_target: exception_pattern (optional, can be string or array)
  ///     disallow: disallowed_pattern (required, can be string or array)
  ///     exclude_disallow: exception_pattern (optional, can be string or array)
  /// ```
  ///
  /// For analysis_options.yaml:
  /// ```yaml
  /// import_rules:
  ///   rules:
  ///     - name: Rule name (optional)
  ///       reason: Why this rule exists (required)
  ///       target: pattern (required, can be string or array)
  ///       exclude_target: exception_pattern (optional, can be string or array)
  ///       disallow: disallowed_pattern (required, can be string or array)
  ///       exclude_disallow: exception_pattern (optional, can be string or array)
  /// ```
  ///
  /// Throws [FormatException] if the YAML is malformed or required fields are missing.
  Config parseRulesFromYaml(String yamlContent, [String? packageName]) {
    final doc = loadYaml(yamlContent);

    if (doc == null) {
      throw FormatException('YAML document is empty');
    }

    if (doc is! Map) {
      throw FormatException('YAML document must be a map');
    }

    // Check if this is an analysis_options.yaml format with import_rules section
    final importRulesSection = doc['import_rules'];
    final rulesData = importRulesSection is Map
        ? importRulesSection['rules']
        : doc['rules'];

    if (rulesData == null) {
      throw FormatException('Missing "rules" key in YAML');
    }

    if (rulesData is! List) {
      throw FormatException('"rules" must be a list');
    }

    final rules = <ImportRule>[];
    for (var i = 0; i < rulesData.length; i++) {
      final ruleMap = rulesData[i];
      if (ruleMap is! Map) {
        throw FormatException('Rule at index $i must be a map');
      }

      try {
        final rule = _parseRule(ruleMap, packageName);
        rules.add(rule);
      } catch (e) {
        throw FormatException('Error parsing rule at index $i: $e');
      }
    }

    return Config(rules: rules);
  }

  /// Parses a single rule from a map.
  ImportRule _parseRule(Map ruleMap, String? packageName) {
    // Parse name (optional)
    final name = ruleMap['name'] as String?;

    // Parse reason (required)
    final reason = ruleMap['reason'];
    if (reason == null) {
      throw FormatException('Missing required field "reason"');
    }
    if (reason is! String) {
      throw FormatException('"reason" must be a string');
    }

    // Parse target (required)
    final targetRaw = ruleMap['target'];
    if (targetRaw == null) {
      throw FormatException('Missing required field "target"');
    }
    final target = _normalizeToList(targetRaw, 'target');

    // Validate that $DIR is not used in target
    for (var i = 0; i < target.length; i++) {
      if (target[i].contains(r'$DIR')) {
        throw FormatException(
          r'$DIR placeholder cannot be used in "target" field',
        );
      }
    }

    // Validate that package: URIs are not used in target
    for (var i = 0; i < target.length; i++) {
      if (target[i].startsWith('package:')) {
        throw FormatException(
          '"target" must use relative file paths (e.g., lib/**, test/**), not package: URIs. Found: ${target[i]}',
        );
      }
    }

    // Parse exclude_target (optional)
    final excludeTargetRaw = ruleMap['exclude_target'];
    final excludeTarget = excludeTargetRaw != null
        ? _normalizeToList(excludeTargetRaw, 'exclude_target')
        : <String>[];

    // Validate that $DIR is not used in exclude_target
    for (var i = 0; i < excludeTarget.length; i++) {
      if (excludeTarget[i].contains(r'$DIR')) {
        throw FormatException(
          r'$DIR placeholder cannot be used in "exclude_target" field',
        );
      }
    }

    // Validate that package: URIs are not used in exclude_target
    for (var i = 0; i < excludeTarget.length; i++) {
      if (excludeTarget[i].startsWith('package:')) {
        throw FormatException(
          '"exclude_target" must use relative file paths (e.g., lib/**, test/**), not package: URIs. Found: ${excludeTarget[i]}',
        );
      }
    }

    // Parse disallow (required)
    final disallowRaw = ruleMap['disallow'];
    if (disallowRaw == null) {
      throw FormatException('Missing required field "disallow"');
    }
    final disallow = _normalizeToList(disallowRaw, 'disallow');

    // Parse exclude_disallow (optional)
    final excludeDisallowRaw = ruleMap['exclude_disallow'];
    final excludeDisallow = excludeDisallowRaw != null
        ? _normalizeToList(excludeDisallowRaw, 'exclude_disallow')
        : <String>[];

    return ImportRule(
      name: name,
      reason: reason,
      targetPatterns: target
          .map((pattern) => TargetPattern(pattern: pattern))
          .toList(),
      excludeTargetPatterns: excludeTarget
          .map((pattern) => TargetPattern(pattern: pattern))
          .toList(),
      disallowPatterns: disallow.map((originalPattern) {
        final normalizedPattern = _normalizeDisallowPattern(
          originalPattern,
          packageName,
        );
        return DisallowPattern(
          pattern: normalizedPattern,
          originalPattern: originalPattern,
        );
      }).toList(),
      excludeDisallowPatterns: excludeDisallow.map((originalPattern) {
        final normalizedPattern = _normalizeDisallowPattern(
          originalPattern,
          packageName,
        );
        return DisallowPattern(
          pattern: normalizedPattern,
          originalPattern: originalPattern,
        );
      }).toList(),
    );
  }

  /// Normalizes a value to a list of strings.
  /// Accepts either a single string or a list of strings.
  List<String> _normalizeToList(dynamic value, String fieldName) {
    if (value is String) {
      return [value];
    } else if (value is List) {
      final result = <String>[];
      for (var i = 0; i < value.length; i++) {
        final item = value[i];
        if (item is! String) {
          throw FormatException(
            '$fieldName[$i] must be a string, got ${item.runtimeType}',
          );
        }
        result.add(item);
      }
      return result;
    } else {
      throw FormatException(
        '$fieldName must be a string or list of strings, got ${value.runtimeType}',
      );
    }
  }
}
