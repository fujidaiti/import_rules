# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`import_rules` is a Dart analyzer plugin that enforces custom import rules in Dart projects. It allows developers to define constraints on which files can import which other files using YAML configuration, enabling architectural patterns like layered architecture, feature isolation, and encapsulation.

## Common Commands

### Testing

```bash
# Run all tests
dart test

# Run a single test file
dart test test/yaml_parser_test.dart

# Run e2e tests
dart test e2e/e2e_test.dart
```

### Linting

```bash
# Analyze the code
dart analyze
```

### Debugging

Plugin logs are written to `.dart_tool/import_rules/instrumentation_*.log` with timestamps. Check these logs when debugging rule matching issues.

## Architecture

### Core Components

**Plugin Entry Point** (`lib/main.dart`):

- `ImportRulesPlugin`: The analyzer plugin that registers the `ImportRuleViolation` lint rule
- `ImportRuleViolation`: The main lint rule that checks import directives against configured rules
- `normalizeUri()`: Converts both `file://` and `package:` URIs to relative paths from package root for consistent matching

**Rule Engine** (`lib/src/import_rule.dart`):

- `ImportRule`: Core rule evaluation logic with the `canImport()` method
- `TargetPattern`: Glob patterns for matching source files
- `DisallowPattern`: Glob patterns for matching disallowed imports, supports `$TARGET_DIR` variable
- Rule evaluation follows a specific order: target → exclude_target → disallow → exclude_disallow

**Configuration Parser** (`lib/src/parser.dart`):

- `ConfigParser`: Loads and parses rules from `import_rules.yaml` or `analysis_options.yaml`
- `_normalizeDisallowPattern()`: Makes patterns format-agnostic by converting `package:<current_pkg>/foo.dart` to `lib/foo.dart`
- `_normalizeReason()`: Converts multi-line YAML strings to single-line format

**Logging** (`lib/src/logger.dart`):

- Per-package logger instances that write to `.dart_tool/import_rules/instrumentation_*.log`
- Logs rule loading, URI normalization, and import decisions

### URI Normalization Strategy

The plugin uses a normalization strategy to make rules format-agnostic:

1. **Source files** are normalized from their URI to relative paths:
   - `file:///path/to/project/lib/main.dart` → `lib/main.dart`
   - `package:import_rules/src/config.dart` → `lib/src/config.dart`

2. **Import URIs** are similarly normalized:
   - `package:import_rules/main.dart` → `lib/main.dart` (internal)
   - `package:flutter/material.dart` → `package:flutter/material.dart` (external)

3. **Disallow patterns** in configuration are normalized:
   - `package:<current_pkg>/foo.dart` → `lib/foo.dart`
   - External packages and `dart:*` imports remain unchanged

This allows a single rule like `disallow: lib/main.dart` to match both `import 'lib/main.dart'` and `import 'package:my_pkg/main.dart'`.

### The $TARGET_DIR Variable

`$TARGET_DIR` is a predefined variable representing the parent directory of the file matched by `target`. It's extracted using `_extractDir()` in `lib/src/import_rule.dart` and substituted into `disallow` and `exclude_disallow` patterns at evaluation time. This enables rules like "files can only import from their own directory" without hardcoding paths.

## Configuration Files

Rules can be defined in either:

- `import_rules.yaml` (dedicated config file)
- `analysis_options.yaml` (under `import_rules:` section)

The parser searches for both and uses the first one found. See `README.md` for detailed rule syntax and `e2e/USE_CASES.md` for real-world examples.

## Testing Strategy

- **Unit tests** (`test/*.dart`): Test individual components like the parser, URI normalization, and rule matching logic
- **E2E tests** (`e2e/e2e_test.dart`): Test the complete plugin behavior by creating temporary projects, running `dart analyze`, and verifying the expected violations are reported
- The e2e framework (`e2e/src/`) provides utilities for creating test projects, running the analyzer, and matching against expected outputs
