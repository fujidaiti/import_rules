import 'package:import_rules/src/import_rule.dart';
import 'package:meta/meta.dart';

@immutable
class Config {
  const Config({required this.rules});

  const Config.empty() : rules = const [];

  final List<ImportRule> rules;
}
