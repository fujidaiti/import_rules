import 'dart:async';

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:analysis_server_plugin/src/plugin_server.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:import_rules/src/config.dart';
import 'package:import_rules/src/import_rule.dart';
import 'package:import_rules/src/parser.dart';

import 'src/logger.dart';

final plugin = ImportRulesPlugin();

late final PluginServer a;

class ImportRulesPlugin extends Plugin {
  @override
  String get name => 'ImportRulesPlugin';

  late final ImportRuleViolation _rule;

  @override
  void register(PluginRegistry registry) {
    _rule = ImportRuleViolation();
    // Enable this rule by default.
    registry.registerWarningRule(_rule);
  }

  @override
  FutureOr<void> shutDown() async {
    await Logger.closeAll();
  }
}

class ImportRuleViolation extends AnalysisRule {
  static const code = LintCode(
    'import_rule_violation',
    'Import rule violation.',
    // `{0}` will be replaced with the reason for an import rule violation.
    correctionMessage: '{0}',
  );

  static final Map<String, Config> _configs = {};

  ImportRuleViolation()
    : super(name: code.name, description: code.problemMessage);

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
    if (_configs.containsKey(package.root.path)) {
      config = _configs[package.root.path]!;
    } else {
      final parser = ConfigParser(logger);
      config = parser.loadConfigurationFor(package);
      _configs[package.root.path] = config;
    }
    if (config.rules.isEmpty) return;

    logger.info('Analyzing: $sourceUri');
    var visitor = _Visitor(this, sourceUri, context, config, logger);
    registry.addImportDirective(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final Uri sourceUri;
  final RuleContext context;
  final Config config;
  final Logger logger;

  _Visitor(this.rule, this.sourceUri, this.context, this.config, this.logger);

  @override
  void visitImportDirective(ImportDirective node) {
    final Import importDirective;
    if (node.libraryImport?.uri case DirectiveUriWithSource(:final source)) {
      importDirective = Import(uri: source.uri.toString());
      logger.info('Analyzing import: $importDirective');
    } else {
      logger.info('Skipping unresolved import: ${node.uri}');
      return;
    }

    for (final rule in config.rules) {
      logger.info('Calling ImportRule.canImport($sourceUri, $importDirective)');
      if (!rule.canImport(sourceUri.toString(), importDirective)) {
        logger.info('Import denied. Reason: ${rule.reason}');
        this.rule.reportAtNode(node, arguments: [rule.reason]);
        return;
      }
    }

    logger.info('Import allowed');
  }
}
