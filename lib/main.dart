import 'dart:async';

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/workspace/workspace.dart';

import 'src/logger.dart';

final plugin = ImportRulesPlugin();

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
  FutureOr<void> shutDown() {
    _rule.dispose();
    return super.shutDown();
  }
}

class ImportRules extends AnalysisRule {
  static const LintCode code = LintCode(
    'import_rules',
    'Import rules',
    correctionMessage: "Try removing 'await'.",
  );
  ImportRules() : super(name: code.name, description: 'Linting import rules');

  final Map<String, Logger> _loggers = {};

  @override
  LintCode get diagnosticCode => code;

  Logger _loggerFor(WorkspacePackage package) {
    final key = package.root.path;
    if (_loggers[key] case final logger?) {
      return logger;
    } else {
      final logger = Logger()..setUpLogger(package);
      _loggers[key] = logger;
      return logger;
    }
  }

  Future<void> dispose() async {
    for (final logger in _loggers.values) {
      await logger.tearDownLogger();
    }
  }

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final package = context.package;
    var sourceUri = context.libraryElement?.uri;
    if (package == null || sourceUri == null) return;
    _loadRules(package);

    final logger = _loggerFor(package);
    logger.info('Analyzing: $sourceUri');
    var visitor = _Visitor(this, sourceUri, context, logger);
    registry.addImportDirective(this, visitor);
  }

  void _loadRules(WorkspacePackage package) {
    const searchPaths = ['import_rules.yaml', 'analysis_options.yaml'];

    // File? rulesFile;
    // for (final searchPath in searchPaths) {
    //   final file = package.getChild(searchPath);
    //   if (file is File && file.exists) {
    //     rulesFile = file;
    //     break;
    //   }
    // }
    // if (rulesFile == null) {
    //   return;
    // }

    // final yaml = rulesFile.readAsStringSync();
    // tryParseRulesFromYaml(yaml);
    // final timestamp = rulesFile.modificationStamp;
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final Uri sourceUri;
  final RuleContext context;
  final Logger logger;

  _Visitor(this.rule, this.sourceUri, this.context, this.logger);

  @override
  void visitImportDirective(ImportDirective node) {
    logger.info(
      'ImportDirective: context: ${context.package?.root.path}, uri: ${node.uri}',
    );
  }
}
