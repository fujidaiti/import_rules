# Capture Group Feature Discussion

Related issue: #12

## Background

Issue #12 originally requested support for `..` in `$TARGET_DIR` patterns to
enable cross-import prevention between sibling directories (Feature Sliced
Design). The discussion led to a proposal for a more general **capture group
syntax**.

### The problem

When enforcing module isolation (e.g., files under `lib/src/entities/a/` cannot
import from `lib/src/entities/b/`), users currently have to write a separate
rule for each module:

```yaml
rules:
  - target: lib/src/entities/a/**
    disallow:
      - lib/src/entities/b/**
      - lib/src/entities/c/**
    reason: Module a cannot depend on other modules.

  - target: lib/src/entities/b/**
    disallow:
      - lib/src/entities/a/**
      - lib/src/entities/c/**
    reason: Module b cannot depend on other modules.
```

This is tedious and must be updated every time a new module is added.

### Proposed syntax

A capture group syntax that allows a single rule to express sibling isolation:

```yaml
rules:
  - target: lib/src/entities/{MODULE}/**
    disallow: lib/src/entities/**
    exclude_disallow: lib/src/entities/$MODULE/**
    reason: Modules under entities/ must be isolated from each other.
```

`{MODULE}` in the `target` pattern captures the matched path segment, and
`$MODULE` substitutes it in `disallow` and `exclude_disallow` patterns.

## Use cases

The capture group feature primarily enables **sibling isolation** — "things in
group X can access their own group but not other groups at the same level." This
pattern appears in several common architectural scenarios:

### Module / slice isolation

The original use case. Prevent cross-imports between sibling modules:

```yaml
- target: lib/src/entities/{MODULE}/**
  disallow: lib/src/entities/**
  exclude_disallow: lib/src/entities/$MODULE/**
  reason: Modules under entities/ must be isolated from each other.
```

### Feature-scoped architecture

In a feature-based architecture, prevent one feature from depending on another
feature's internals:

```yaml
- target: lib/features/{FEATURE}/presentation/**
  disallow: lib/features/**
  exclude_disallow: lib/features/$FEATURE/**
  reason: A feature's presentation layer cannot depend on other features.
```

### Platform-specific code isolation

Prevent platform implementations from depending on each other:

```yaml
- target: lib/platforms/{PLATFORM}/**
  disallow: lib/platforms/**
  exclude_disallow: lib/platforms/$PLATFORM/**
  reason: Platform implementations must be independent.
```

### Test-to-source scoping

Ensure test files only import from their corresponding source module:

```yaml
- target: test/{MODULE}/**
  disallow: lib/src/**
  exclude_disallow: lib/src/$MODULE/**
  reason: Tests should only access their own module's internals.
```

### Barrel file enforcement (limited)

Allowing imports of other modules only through their barrel files:

```yaml
- target: lib/modules/{MODULE}/**
  disallow: lib/modules/**
  exclude_disallow:
    - lib/modules/$MODULE/**
    - lib/modules/*/*.dart # allow top-level barrel files
  reason: Import other modules through their barrel files, not their internals.
```

Note: This requires a project convention that only barrel files live at the
module root directory (all other files go in `src/`). Glob patterns cannot
express "the filename must match its parent directory name" (e.g.,
`lib/modules/auth/auth.dart`), so `lib/modules/*/*.dart` is used as an
approximation.

## Relationship with `$TARGET_DIR`

`$TARGET_DIR` is an existing variable that resolves to the direct parent
directory of the matched target file. The capture group feature has significant
overlap with it.

### How they differ

| | `$TARGET_DIR` | Capture groups |
| --- | --- | --- |
| Derived from | Actual file path | Pattern matching |
| Depth handling | Arbitrary (always the direct parent) | Fixed (captures a specific segment) |
| Requires knowing structure | No | Yes |

### Can capture groups replace `$TARGET_DIR`?

The theoretical advantage of `$TARGET_DIR` is depth-agnostic rules:

```yaml
# "Every file can only import from its own directory"
- target: lib/**
  disallow: lib/**
  exclude_disallow: $TARGET_DIR/**
```

This works for files at any nesting level without specifying the structure.
Capture groups would require a separate rule per depth level.

However, in practice, architectural constraints are always defined at a
**specific, known level** in the directory tree. You know where the isolation
boundary is because you designed the structure intentionally. No practical use
case was identified where the arbitrary-depth behavior of `$TARGET_DIR` is
needed and capture groups wouldn't fit.

### Conclusion

Capture groups can replace `$TARGET_DIR` for all practical use cases. Having
both would mean two overlapping concepts to document and maintain. Introducing
only capture groups keeps the API simpler and more expressive.
