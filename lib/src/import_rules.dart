import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Represents an import rule that controls which files can import which files.
class Rule {
  /// Optional name for the rule (used in error messages).
  final String? name;

  /// Required reason explaining why this rule exists.
  final String reason;

  /// File patterns to which this rule applies.
  final List<String> target;

  /// File patterns to exclude from target.
  final List<String> excludeTarget;

  /// File patterns that files matching target cannot import.
  final List<String> disallow;

  /// File patterns to exclude from disallow (making them importable).
  final List<String> excludeDisallow;

  Rule({
    this.name,
    required this.reason,
    required this.target,
    this.excludeTarget = const [],
    required this.disallow,
    this.excludeDisallow = const [],
  });
}

/// Checks if a target file can import an importee file according to the given rule.
///
/// Returns `true` if the import is allowed, `false` if it's denied.
///
/// The evaluation follows this logic:
/// 1. If targetFile doesn't match any target pattern, the rule doesn't apply (return true)
/// 2. If targetFile matches any excludeTarget pattern, the rule doesn't apply (return true)
/// 3. Extract $DIR from targetFile's parent directory
/// 4. If importeeFile doesn't match any disallow pattern, the import is allowed (return true)
/// 5. If importeeFile matches any excludeDisallow pattern (with $DIR substituted), the import is allowed (return true)
/// 6. Otherwise, the import is denied (return false)
bool canImport(String targetFile, String importeeFile, Rule rule) {
  // Step 1: Check if targetFile matches any target pattern
  if (!_matchesAnyPattern(targetFile, rule.target)) {
    return true; // Rule doesn't apply
  }

  // Step 2: Check if targetFile matches any excludeTarget pattern
  if (_matchesAnyPattern(targetFile, rule.excludeTarget)) {
    return true; // Rule doesn't apply
  }

  // Step 3: Extract $DIR from targetFile's parent directory
  final dir = _extractDir(targetFile);

  // Step 4: Check if importeeFile matches any disallow pattern
  if (!_matchesAnyPattern(importeeFile, rule.disallow)) {
    return true; // Import is allowed (not in disallow list)
  }

  // Step 5: Check if importeeFile matches any excludeDisallow pattern (with $DIR substituted)
  final excludeDisallowWithDir =
      rule.excludeDisallow
          .map((pattern) => _substituteDir(pattern, dir))
          .toList();
  if (_matchesAnyPattern(importeeFile, excludeDisallowWithDir)) {
    return true; // Import is allowed (in exclude list)
  }

  // Step 6: Import is denied
  return false;
}

/// Checks if a path matches any of the given glob patterns.
bool _matchesAnyPattern(String path, List<String> patterns) {
  if (patterns.isEmpty) {
    return false;
  }

  for (final pattern in patterns) {
    final glob = Glob(pattern);
    if (glob.matches(path)) {
      return true;
    }
  }

  return false;
}

/// Extracts the parent directory from a file path.
///
/// For example:
/// - "lib/features/auth/src/utils.dart" -> "lib/features/auth/src"
/// - "lib/main.dart" -> "lib"
/// - "package:flutter/material.dart" -> "package:flutter"
String _extractDir(String filePath) {
  // Handle package imports differently
  if (filePath.startsWith('package:')) {
    final lastSlash = filePath.lastIndexOf('/');
    if (lastSlash == -1) {
      return filePath; // No directory component
    }
    return filePath.substring(0, lastSlash);
  }

  // For file paths, use the path package
  return p.dirname(filePath);
}

/// Replaces $DIR placeholder in a pattern with the actual directory value.
///
/// For example:
/// - pattern: "$DIR/**", dirValue: "lib/features/auth/src" -> "lib/features/auth/src/**"
/// - pattern: "lib/**", dirValue: "lib/features/auth/src" -> "lib/**" (no change)
String _substituteDir(String pattern, String dirValue) {
  return pattern.replaceAll(r'$DIR', dirValue);
}

List<Rule>? tryParseRulesFromYaml(String yamlContent) {
  try {
    return parseRulesFromYaml(yamlContent);
  } on FormatException catch (error, stackTrace) {
    print('Error parsing rules from YAML: $error');
    print('Stack trace: $stackTrace');
    return null;
  }
}

/// Parses import rules from a YAML string.
///
/// The YAML should follow this structure:
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
/// Throws [FormatException] if the YAML is malformed or required fields are missing.
List<Rule> parseRulesFromYaml(String yamlContent) {
  final doc = loadYaml(yamlContent);

  if (doc == null) {
    throw FormatException('YAML document is empty');
  }

  if (doc is! Map) {
    throw FormatException('YAML document must be a map');
  }

  final rulesData = doc['rules'];
  if (rulesData == null) {
    throw FormatException('Missing "rules" key in YAML');
  }

  if (rulesData is! List) {
    throw FormatException('"rules" must be a list');
  }

  final rules = <Rule>[];
  for (var i = 0; i < rulesData.length; i++) {
    final ruleMap = rulesData[i];
    if (ruleMap is! Map) {
      throw FormatException('Rule at index $i must be a map');
    }

    try {
      final rule = _parseRule(ruleMap);
      rules.add(rule);
    } catch (e) {
      throw FormatException('Error parsing rule at index $i: $e');
    }
  }

  return rules;
}

/// Parses import rules from a YAML file.
///
/// Throws [FormatException] if the YAML is malformed or required fields are missing.
/// Throws [FileSystemException] if the file cannot be read.
List<Rule> parseRulesFromYamlFile(String filePath) {
  final file = File(filePath);
  final content = file.readAsStringSync();
  return parseRulesFromYaml(content);
}

/// Parses a single rule from a map.
Rule _parseRule(Map ruleMap) {
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

  // Parse exclude_target (optional)
  final excludeTargetRaw = ruleMap['exclude_target'];
  final excludeTarget =
      excludeTargetRaw != null
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

  // Parse disallow (required)
  final disallowRaw = ruleMap['disallow'];
  if (disallowRaw == null) {
    throw FormatException('Missing required field "disallow"');
  }
  final disallow = _normalizeToList(disallowRaw, 'disallow');

  // Parse exclude_disallow (optional)
  final excludeDisallowRaw = ruleMap['exclude_disallow'];
  final excludeDisallow =
      excludeDisallowRaw != null
          ? _normalizeToList(excludeDisallowRaw, 'exclude_disallow')
          : <String>[];

  return Rule(
    name: name,
    reason: reason,
    target: target,
    excludeTarget: excludeTarget,
    disallow: disallow,
    excludeDisallow: excludeDisallow,
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
