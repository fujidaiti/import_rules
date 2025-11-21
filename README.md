# Dart Import Lint Tool Specification

## 1. Overview

A lint tool for Dart language that controls which files can import which files. Uses YAML for configuration files, enabling flexible rule definitions.

## 2. Configuration File Structure

### 2.1 Basic Structure

```yaml
rules:
  - name: Rule name
    reason: Why this rule exists
    target: pattern
    exclude_target: exception_pattern
    disallow: disallowed_pattern
    exclude_disallow: exception_pattern
```

**For multiple elements, use array format:**

```yaml
rules:
  - name: Rule name
    reason: Why this rule exists
    target:
      - pattern1
      - pattern2
    disallow:
      - disallowed_pattern1
      - disallowed_pattern2
```

### 2.2 Fields

#### `name` (optional)

Rule identifier name. Used in error messages.

#### `reason` (required)

Reason for the rule. Required for developers to understand the intent of the rule.

#### `target` (required)

File patterns to which this rule applies. Use string for single element, array for multiple elements.

```yaml
# Single element
target: lib/presentation/**

# Multiple elements
target:
  - lib/presentation/**
  - lib/ui/**
```

#### `exclude_target` (optional)

File patterns to exclude from `target`. Use string for single element, array for multiple elements.

#### `disallow` (required)

File patterns that files matching `target` cannot import. Use string for single element, array for multiple elements.

#### `exclude_disallow` (optional)

File patterns to exclude from `disallow` (making them importable). Use string for single element, array for multiple elements.

## 3. Pattern Syntax

### 3.1 Glob Pattern

Default pattern notation. Can be written without quotes.

**Syntax:**

- `*` - Any string within a single directory level (does not include `/`)
- `**` - Any directory levels
- `?` - Any single character

**Examples:**

```yaml
target:
  - lib/presentation/**
  - lib/features/*/models/*.dart
  - test/**_test.dart
```

### 3.2 Predefined Variable: $DIR

`$DIR` is a predefined variable representing the `parent directory path of the file matched by target`.

**Where it can be used:**

- `disallow`
- `exclude_disallow`

**Constraints:**

- `$DIR` is automatically determined from the file matched by `target`
- Cannot be used in `target` itself

**Behavior:**

```yaml
target:
  - lib/features/auth/src/utils.dart
```

In this case, `$DIR = lib/features/auth/src`

**Example:**

```yaml
target:
  - "**"
disallow:
  - "**/src/**"
exclude_disallow:
  - "$DIR/**"
```

**Behavior:**

- `lib/features/auth/src/utils.dart` matches → `DIR=lib/features/auth/src`
- `disallow` prohibits all files under `src/`
- `exclude_disallow: lib/features/auth/src/**` → excludes own directory
- Result: Only files within the same `src/` directory can be imported

## 4. Evaluation Rules

### 4.1 Matching Order

1. Check if the file matches the `target` pattern
2. If it matches `exclude_target`, this rule does not apply
3. Check if the imported file matches `disallow`
4. If it matches `exclude_disallow`, the import is allowed

### 4.2 Evaluation Flowchart

```mermaid
flowchart TD
    Start([File A imports File B]) --> CheckTarget{Does File A<br/>match target?}
    CheckTarget -->|No| NextRule[Next Rule]
    CheckTarget -->|Yes| CheckExcludeTarget{Does File A<br/>match exclude_target?}
    CheckExcludeTarget -->|Yes| NextRule
    CheckExcludeTarget -->|No| ExtractDIR[DIR = Parent directory path of File A]
    ExtractDIR --> CheckDisallow{Does File B<br/>match disallow?}
    CheckDisallow -->|No| Allow[Import Allowed]
    CheckDisallow -->|Yes| CheckExcludeDisallow{Does File B<br/>match exclude_disallow?}
    CheckExcludeDisallow -->|Yes| Allow
    CheckExcludeDisallow -->|No| Deny[Import Denied<br/>Error]
    NextRule --> End([End])
    Allow --> End
    Deny --> End
    
    style Start fill:#e1f5ff
    style End fill:#e1f5ff
    style Allow fill:#d4edda
    style Deny fill:#f8d7da
```

### 4.3 Multiple Rules

When multiple rules are defined, all rules are evaluated independently. If any rule prohibits the import, that import results in an error.

## 5. YAML Syntax Notes

### 5.1 Quotation

Quotes are not required except in the following cases:

```yaml
# Quotes not required
target:
  - lib/presentation/**
  - package:flutter/material.dart

# Quotes required (when only **)
disallow:
  - "**"
```

### 5.2 Comments

Standard YAML comment notation can be used.

```yaml
rules:
  # Presentation layer rules
  - name: Presentation isolation
    reason: Keep presentation layer clean
    target:
      - lib/presentation/**
    disallow:
      - lib/data/**  # Direct data access forbidden
```
