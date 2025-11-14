import 'dart:async';

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

final plugin = SimplePlugin();

class SimplePlugin extends Plugin {
  @override
  String get name => 'SimplePlugin';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(MyRule());
  }

  @override
  FutureOr<void> start() {
    // TODO: implement start
    return super.start();
  }
}

class MyRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'simple_plugin',
    'No await expressions ohhhhhhhhhhh',
    correctionMessage: "Try removing 'await'.",
  );

  MyRule()
    : super(name: code.name, description: 'A longer description of the rule.');

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    var visitor = _Visitor(this, context);
    registry.addAwaitExpression(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  final RuleContext context;

  _Visitor(this.rule, this.context);

  @override
  void visitAwaitExpression(AwaitExpression node) {
    rule.reportAtNode(node);
  }
}
