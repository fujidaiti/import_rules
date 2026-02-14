import 'package:import_rules/src/import_rule.dart';
import 'package:meta/meta.dart';

@immutable
class Config {
  const Config({
    required this.rules,
    this.defaultSeverity,
    this.configFilePath,
    this.modificationStamp,
  });

  const Config.empty()
    : rules = const [],
      defaultSeverity = null,
      configFilePath = null,
      modificationStamp = null;

  final List<ImportRule> rules;

  /// The global default severity from the config file.
  /// If null, defaults to [Severity.warning].
  final Severity? defaultSeverity;

  final String? configFilePath;
  final int? modificationStamp;
}
