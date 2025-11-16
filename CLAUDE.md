# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Dart analyzer plugin that enforces import rules in Dart projects. It validates that files only import allowed dependencies based on configurable YAML rules, enabling enforcement of architectural boundaries (e.g., layer separation, feature module isolation, src/ encapsulation).

## Architecture

### Core Components

1. **Plugin Entry Point** (`lib/main.dart`)
   - `ImportRulesPlugin`: Analyzer plugin that registers the lint rule
   - `ImportRules`: The main `AnalysisRule` that processes import directives
   - Maintains a cache of parsed configs per package root path

2. **Rule Engine** (`lib/src/import_rules.dart`)
   - `ImportRule`: Data class representing a single rule with target/disallow/exclude patterns
   - `ImportRule.canImport()`: Method implementing the rule matching algorithm
   - Supports glob patterns and the `$DIR` predefined variable for dynamic path substitution

3. **Configuration Parser** (`lib/src/parser.dart`)
   - `ConfigParser`: Loads and parses rules from YAML files
   - Searches for `import_rules.yaml` first, then `analysis_options.yaml`
   - Validates required fields (`reason`, `target`, `disallow`)
   - Prevents `$DIR` usage in `target` and `exclude_target` fields

4. **Configuration Model** (`lib/src/config.dart`)
   - `Config`: Immutable container for a list of `ImportRule` objects

5. **Logging** (`lib/src/logger.dart`)
   - Per-package logger instances for debugging rule evaluation

### Rule Evaluation Algorithm

The `ImportRule.canImport()` method in `lib/src/import_rules.dart:44` implements this logic:

1. Check if target file matches any `target` pattern → if not, rule doesn't apply
2. Check if target file matches any `exclude_target` pattern → if yes, rule doesn't apply
3. Extract `$DIR` from target file's parent directory
4. Check if importee matches any `disallow` pattern → if not, import allowed
5. Check if importee matches any `exclude_disallow` pattern (with `$DIR` substituted) → if yes, import allowed
6. Otherwise, import is denied

### Key Design Patterns

- **$DIR Variable**: Dynamically resolved to the parent directory of the file being analyzed. Used in `disallow`/`exclude_disallow` to create rules like "files can only import from their own src/ directory"
- **Pattern Matching**: Uses the `glob` package for flexible file pattern matching
- **Caching**: Config objects are cached per package root to avoid re-parsing on every file analysis

## Development Commands

### Testing
```bash
# Run all tests
dart test

# Run specific test file
dart test test/yaml_parser_test.dart
dart test test/primitive_behaviors_test.dart
dart test test/import_rules_expr_test.dart

# Run tests with verbose output
dart test --reporter expanded
```

### Build and Analyze
```bash
# Analyze code
dart analyze

# Format code
dart format .

# Check formatting without modifying files
dart format --output=none --set-exit-if-changed .
```

### Plugin Development
This is an analyzer plugin that gets loaded by the Dart analyzer. To test it:
1. Add the plugin to `analysis_options.yaml`:
   ```yaml
   plugins:
     import_rules:
       path: ./
   ```
2. Run analysis in a test project that uses this plugin

## Configuration File Format

Rules are defined in `import_rules.yaml` or within `analysis_options.yaml`. See the README.md for full specification, but key points:

- **Required fields**: `reason`, `target`, `disallow`
- **Optional fields**: `name`, `exclude_target`, `exclude_disallow`
- **Pattern types**: Glob patterns (`**/*.dart`, `lib/features/*/models/*.dart`)
- **$DIR variable**: Only usable in `disallow` and `exclude_disallow`, resolves to parent directory of matched target file

## Important Implementation Details

### Pattern Validation
- `$DIR` cannot be used in `target` or `exclude_target` (validated in `lib/src/parser.dart:121-126`)
- All patterns must be valid glob patterns compatible with the `glob` package

### Package URI Handling
The `_extractDir()` function in `lib/src/import_rules.dart:99` handles both:
- File paths: `lib/features/auth/src/utils.dart` → `lib/features/auth/src`
- Package URIs: `package:flutter/material.dart` → `package:flutter`

### Analyzer Integration
The plugin uses `analysis_server_plugin` v0.3.3 and `analyzer` v8.4.0. The visitor pattern (`_Visitor` class) is registered to process `ImportDirective` AST nodes during analysis.

## Testing Strategy

Tests are organized into three categories:
1. **primitive_behaviors_test.dart**: Core rule matching logic tests
2. **import_rules_expr_test.dart**: Expression evaluation and pattern matching tests
3. **yaml_parser_test.dart**: YAML configuration parsing tests

When adding new features, ensure all three layers are tested appropriately.
