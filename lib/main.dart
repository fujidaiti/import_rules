import 'dart:async';
import 'dart:math' show min;

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:analysis_server_plugin/src/plugin_server.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/utilities/extensions/uri.dart';
import 'package:import_rules/src/config.dart';
import 'package:import_rules/src/parser.dart';

import 'src/logger.dart';

final plugin = ImportRulesPlugin();

late final PluginServer a;

class ImportRulesPlugin extends Plugin {
  @override
  String get name => 'ImportRules';

  late final ImportRules _rule;

  @override
  void register(PluginRegistry registry) {
    _rule = ImportRules();
    registry.registerWarningRule(_rule);
  }

  @override
  FutureOr<void> shutDown() async {
    await Logger.closeAll();
  }
}

class ImportRules extends AnalysisRule {
  static const LintCode code = LintCode(
    'import_rules',
    'Import rules',
    correctionMessage: "Try removing 'await'.",
  );

  static final Map<String, Config> _configs = {};

  ImportRules() : super(name: code.name, description: 'Linting import rules');

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
    // if (config.rules.isEmpty) return;

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
    node.libraryImport?.importedLibrary?.uri.isImplementation;
    min(1, 2);
    logger.info(
      'ImportDirective: type: ${node.libraryImport?.uri.runtimeType} uri: ${node.uri}',
    );
  }
}
