import 'dart:async';

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/workspace/workspace.dart';
import 'package:import_rules/src/config.dart';
import 'package:import_rules/src/import_rule.dart';
import 'package:import_rules/src/parser.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'src/logger.dart';

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

/// Normalizes a URI to a relative path from the package root.
///
/// Converts both file:// and package: URIs to relative paths:
/// - file:///Users/user/project/lib/main.dart -> lib/main.dart
/// - package:import_rules/src/config.dart -> lib/src/config.dart
/// - package:flutter/material.dart -> package:flutter/material.dart (external)
@visibleForTesting
String normalizeUri(Uri uri, String packageRootPath, String packageName) {
  if (uri.scheme == 'file') {
    // Convert file:// URI to relative path from package root
    final filePath = uri.toFilePath();
    return p.relative(filePath, from: packageRootPath);
  } else if (uri.scheme == 'package') {
    // Check if this is a package URI for the current package
    final uriString = uri.toString();
    final packagePrefix = 'package:$packageName/';

    if (uriString.startsWith(packagePrefix)) {
      // Internal package URI: strip prefix and prepend 'lib/'
      final pathAfterPackage = uriString.substring(packagePrefix.length);
      return 'lib/$pathAfterPackage';
    } else {
      // External package URI: keep as-is
      return uriString;
    }
  }

  // Fallback: return as-is (shouldn't happen in practice)
  return uri.toString();
}

final plugin = _ImportRulesPlugin();

class _ImportRulesPlugin extends Plugin {
  @override
  String get name => 'ImportRulesPlugin';

  late final _Rule _rule;

  @override
  void register(PluginRegistry registry) {
    _rule = _Rule();
    // Enable this rule by default.
    registry.registerWarningRule(_rule);
  }

  @override
  FutureOr<void> shutDown() async {
    await Logger.closeAll();
  }
}

class _Rule extends AnalysisRule {
  static const code = LintCode(
    'import_rule_violation',
    'Import rule violation.',
    // `{0}` will be replaced with the reason for an import rule violation.
    correctionMessage: '{0}',
  );

  static final Map<String, Config> _configs = {};
  static final Map<String, String> _packageNames = {};
  final parser = ConfigParser();

  _Rule() : super(name: code.name, description: code.problemMessage);

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final package = context.package;
    var sourceUri = context.libraryElement?.uri;
    if (package == null || sourceUri == null) return;

    final logger = Logger.of(package);

    final Config config;
    final String packageName;

    if (_configs.containsKey(package.root.path)) {
      config = _configs[package.root.path]!;
      packageName = _packageNames[package.root.path]!;
    } else {
      config = parser.loadConfigurationFor(package);
      _configs[package.root.path] = config;

      for (final rule in config.rules) {
        logger?.info('Rule loaded:');
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

      final name = _getPackageName(package);
      if (name == null) {
        logger?.warning('Could not determine package name from pubspec.yaml');
        return;
      }
      packageName = name;
      _packageNames[package.root.path] = packageName;
    }
    if (config.rules.isEmpty) return;

    logger?.info('Analyzing: $sourceUri');
    final normalizedSourceUri = normalizeUri(
      sourceUri,
      package.root.path,
      packageName,
    );
    logger?.info('Normalized to: $normalizedSourceUri');
    var visitor = _Visitor(
      this,
      normalizedSourceUri,
      context,
      config,
      logger,
      packageName,
    );
    registry.addImportDirective(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final String sourceUri;
  final RuleContext context;
  final Config config;
  final Logger? logger;
  final String packageName;

  _Visitor(
    this.rule,
    this.sourceUri,
    this.context,
    this.config,
    this.logger,
    this.packageName,
  );

  @override
  void visitImportDirective(ImportDirective node) {
    final Import importDirective;
    if (node.libraryImport?.uri case DirectiveUriWithSource(:final source)) {
      final package = context.package!;
      final normalizedImportUri = normalizeUri(
        source.uri,
        package.root.path,
        packageName,
      );
      importDirective = Import(uri: normalizedImportUri);
      logger?.info('Analyzing import: ${source.uri} -> $importDirective');
    } else {
      logger?.info('Skipping unresolved import: ${node.uri}');
      return;
    }

    for (final rule in config.rules) {
      logger?.info(
        'Calling ImportRule.canImport($sourceUri, $importDirective)',
      );
      if (!rule.canImport(sourceUri, importDirective)) {
        logger?.info('Import denied. Reason: ${rule.reason}');
        this.rule.reportAtNode(node, arguments: [rule.reason]);
        return;
      }
    }

    logger?.info('Import allowed');
  }
}
