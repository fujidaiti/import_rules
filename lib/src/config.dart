import 'package:import_rules/src/import_rule.dart';
import 'package:meta/meta.dart';

@immutable
class Config {
  const Config({
    required this.rules,
    this.configFilePath,
    this.modificationStamp,
  });

  const Config.empty()
      : rules = const [],
        configFilePath = null,
        modificationStamp = null;

  final List<ImportRule> rules;
  final String? configFilePath;
  final int? modificationStamp;
}
