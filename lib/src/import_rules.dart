import 'package:glob/glob.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

/// Represents an import directive in a Dart file.
@immutable
class Import {
  const Import({required this.uri});

  final String uri;
}

/// Represents an import rule that controls which files can import which files.
class ImportRule {
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

  ImportRule({
    this.name,
    required this.reason,
    required this.target,
    this.excludeTarget = const [],
    required this.disallow,
    this.excludeDisallow = const [],
  });

  /// Checks if a target file can import an importee file according to this rule.
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
  bool canImport(String targetFile, Import importee) {
    // Step 1: Check if targetFile matches any target pattern
    if (!_matchesAnyPattern(targetFile, target)) {
      return true; // Rule doesn't apply
    }

    // Step 2: Check if targetFile matches any excludeTarget pattern
    if (_matchesAnyPattern(targetFile, excludeTarget)) {
      return true; // Rule doesn't apply
    }

    // Step 3: Extract $DIR from targetFile's parent directory
    final dir = _extractDir(targetFile);

    // Step 4: Check if importeeFile matches any disallow pattern
    if (!_matchesAnyPattern(importee.uri, disallow)) {
      return true; // Import is allowed (not in disallow list)
    }

    // Step 5: Check if importeeFile matches any excludeDisallow pattern (with $DIR substituted)
    final excludeDisallowWithDir =
        excludeDisallow.map((pattern) => _substituteDir(pattern, dir)).toList();
    if (_matchesAnyPattern(importee.uri, excludeDisallowWithDir)) {
      return true; // Import is allowed (in exclude list)
    }

    // Step 6: Import is denied
    return false;
  }
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

// Parser functions moved to parser.dart (part of this library).
