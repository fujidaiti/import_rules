# import_rules

A [lint plugin](https://dart.dev/tools/analyzer-plugins) for the Dart analyzer that enforces custom import rules in your projects. Control which files can import which other files using simple YAML configuration, enabling everything from simple allow/disallow lists to complex module dependency constraints for architectural patterns such as layered architecture, feature isolation, and encapsulation.

> [!IMPORTANT]
> Dart SDK 3.10.0+ (Flutter SDK 3.38.0+) is required to enable Dart analyzer plugins.

## Getting started

### 1. Install plugin

Add `import_rules` to the top-level `plugins` section of your `analysis_options.yaml`. You don't need to add the plugin to the dependencies in `pubspec.yaml`.

```yaml
plugins:
  import_rules: ^<latest-version> # e.g., ^0.0.1
```

### 2. Define rules

The rules are defined either in the top-level `import_rules` section of `analysis_options.yaml` or in the top-level `import_rules.yaml` file in the project root. See the [spec](RULES_FILE_SPEC.md) for more details about the rule syntax, and the [Case studies](#case-studies) section for practical examples of the rules file.

```yaml
# analysis_options.yaml

plugins:
  ...

import_rules:
  rules:
    - reason: The domain layer should not depend on other layers and external packages with a few exceptions.
      target: lib/domain/**
      disallow: "**"
      exclude_disallow:
        - lib/domain/**
        - package:uuid/uuid.dart
        - dart:collection
        - dart:math
```

```yaml
# import_rules.yaml

rules:
  - reason: The domain layer should not depend on other layers and external packages with a few exceptions.
    target: lib/domain/**
    ...
```

### 3. Analyze your code

The plugin and rules are automatically loaded when the dart analysis server starts, for example, when you run `dart analyze` in console or launch your IDE. Just like other lint rules, you can see the lint errors in the output of `dart analyze` or in dedicated places within the IDE, such as VSCode's "Problems" panel.

> [!NOTE]
> For IDEs, you may need to restart the analysis server to apply new configurations after modifying the rule file. For VSCode, open the Command Palette and run either `Developer: Reload Window` or `Dart: Restart Analysis Server`. This workaround is expected to be removed in a future release (see issue [#4](https://github.com/fujidaiti/import_rules/issues/4)).

![error-in-editor](https://github.com/user-attachments/assets/0a602219-a237-479f-943a-111f7ad0e074)
![error-in-problems-pane](https://github.com/user-attachments/assets/66133f62-734c-492e-99b3-16ce0ab107c0)

</br>

## Case studies

Here's a list of rules file examples for practical use cases.

### Keep domain layer pure

In a layered architecture, the domain layer should remain free from external dependencies to maintain purity and testability. Only specific, carefully chosen packages (like UUID generators or core Dart libraries) should be allowed as exceptions.

```file tree
lib/
  domain/
    domain.dart
    src/entity.dart
  repository/
    repository.dart
    user_repository.dart
    product_repository.dart
```

```import_rules.yaml
rules:
  - target: lib/domain/**
    disallow: "**"
    exclude_disallow:
      - lib/domain/**
      - package:uuid/uuid.dart
      - dart:collection
      - dart:math
    reason: |
      The domain layer should not depend on other layers
      and external packages with a few exceptions.
```

### Downward dependencies only

Enforce that files can only import from the same directory level or deeper, preventing upward dependencies. This creates a clear dependency hierarchy where higher-level directories cannot depend on lower-level ones.

```file tree
lib/
  main.dart
  features/
    features.dart
    auth/
      auth.dart
      auth_utils.dart
    cart/
      cart.dart
```

```import_rules.yaml
rules:
  - target: "**"
    disallow: "**"
    exclude_disallow: "$TARGET_DIR/**"
    reason: Files can only import from same or deeper directory levels.
```

### Enforce unidirectional layer dependencies

In a layered architecture, the layers should have unidirectional dependencies, where lower layers cannot depend on higher layers.
For example, suppose we have 4 layers: domain, persistence, application, and presentation. Since the domain layer is the lowest layer, it should not depend on other layers. The persistence layer can depend on the domain layer. The application layer orchestrates business logic, so it can depend on the persistence layer. The presentation layer displays the data, so it should depend only on the application layer.

```file tree
lib/
  domain/
  persistence/
  application/
  presentation/
```

```import_rules.yaml
rules:
  - target: lib/domain/**
    disallow: lib/**
    exclude_disallow: lib/domain/**
    reason: Domain layer should not depend on other layers.

  - target: lib/persistence/**
    disallow:
      - lib/application/**
      - lib/presentation/**
    reason: Persistence layer can not depend on application and presentation layers.

  - target: lib/application/**
    disallow: lib/presentation/**
    reason: Application layer can not depend on presentation layer.
    
  - target: lib/presentation/**
    disallow:
      - lib/persistence/**
      - lib/domain/**
    reason: Presentation layer should depend only on application layer.
```

### Feature module isolation

In a feature-driven architecture, each feature should be isolated from other features. The only exception is the "core" module, which can be shared between features.

```file tree
lib/
  features/
    core/
    auth/
    profile/
```

```import_rules.yaml
rules:
  - target: lib/features/**
    disallow: lib/features/**
    exclude_disallow:
      - $TARGET_DIR/** # Allow internal dependencies within the same feature.
      - lib/features/core/**
    reason: Features should be isolated from each other except the core module.
```

### Enforcing custom component usage

Suppose we have custom Flutter widgets in `lib/components/`, such as `Text` and `FilledButton`, that are styled based on our company's design system. We want our team members to always use these custom widgets instead of directly using built-in Material and Cupertino widgets. The custom components, however, should be allowed to import built-in widgets as an exception, since our components are basically wrappers around the built-in widgets.

```yaml
rules:
  - target: lib/**
    exclude_target: lib/components/**
    disallow:
      - package:flutter/material.dart
      - package:flutter/cupertino.dart
      - package:flutter/widgets.dart
    reason: |
      Use custom components in lib/components/ instead of directly importing 
      the built-in Material and Cupertino widgets.
```

```file tree
lib/
  components/
    text.dart
    filled_button.dart
    common.dart
  view/
    home_view.dart
```

```dart
// lib/components/text.dart

import 'package:flutter/material.dart' as m; // Allowed as an exception

class Text extends StatelessWidget {
  ...
  Widget build(BuildContext context) {
    return m.Text(
      // Apply our design here
    );
  }
}
```

```dart
// lib/components/common.dart

// This file exports some of the built-in widgets that can be used as-is without any additional styling.
export 'package:flutter/material.dart' show GestureDetector, ListView, SingleChildScrollView, ...;
```

```dart
// lib/view/home_view.dart

import 'package:flutter/material.dart'; // Not allowed
import 'package:my_app/components/text.dart'; // OK
import 'package:my_app/components/common.dart'; // OK
```

### Legacy code deprecation

A long-lived application may have some legacy code that is no longer actively developed, but still used by other parts of the codebase because it is in the middle of migration to a new architecture, or for backward compatibility reasons. Newly added features, however, should not depend on such legacy code.

```file tree
lib/
  features/
    auth/ # New auth module
    profile/ # Still depends on legacy auth module
    feed/ # newly added module
    legacy/
      auth/ # Legacy auth module 
```

```import_rules.yaml
rules:
  - target: lib/features/**
    exclude_target:
      - lib/features/legacy/** # Legacy code can depend on other legacy code.
      - lib/features/profile/** # Profile module is still using legacy code.
    disallow: lib/features/legacy/**
    reason: Newly added features should not depend on legacy code.
```

### Forbid IO operations in unit tests

In unit tests, we should not perform any IO operations.

```file tree
lib/
  main.dart
test/
  unit/
    domain_test.dart
```

```import_rules.yaml
rules:
  - target: test/unit/**
    disallow: dart:io
```

### Prefer aggregate file imports over individual file imports

An aggregate file is a file that controls which components (classes, functions, etc.) defined in the subdirectories can be visible from the outside. An aggregate file, which is typically named the same as the parent directory, would look like this:

```lib/domain/domain.dart
// All public components in entity.dart can be visible from the outside.
export 'src/entity.dart';

// Only Value class can be visible from the outside.
export 'value.dart' show Value;
```

To make the aggregate file work, we need to forbid importing the individual files directly. For example, we should allow `import 'domain/domain.dart';` but disallow `import 'domain/entity.dart';` and `import 'domain/value.dart';` in the outside of the domain module.

```file tree
lib/
  main.dart
  application/
    application.dart
  domain/
    domain.dart
    value.dart
    src/entity.dart
```

```yaml
rules:
  - target: lib/**
    exclude_target: lib/domain/**
    disallow: lib/domain/**
    exclude_disallow: lib/domain/domain.dart
    reason: Import "domain/domain.dart" instead of directly importing "domain/**/*.dart".
```

### Implementation detail encapsulation

Suppose our team has a naming convention for Dart files where the name of an implementation file should have a prefix of an underscore. Implementation files are created by splitting a large file into smaller ones for readability and maintainability, but should not be visible from the outside (similar to `part` and `part of` keywords). For this reason, such implementation files should be imported only from the same directory.

```file tree
lib/
  main.dart
  cache/
    cache.dart
    _cache_file_loader.dart
    _cache_table.dart
    _cache_hash_algorithm.dart
    utils/
      utils.dart
```

With the above file tree, `lib/cache/cache.dart` should be the only file that can import `_cache_*.dart` files. The others including `lib/cache/utils/utils.dart` should not be able to import `_cache_*.dart` files because they are not in the same directory as the implementation files.

```import_rules.yaml
rules:
  - target: lib/**
    disallow: _*.dart
    # Allow to depend on implementation files within the same directory.
    exclude_disallow: $TARGET_DIR/_*.dart 
    reason: Implementation files should not be imported directly.
```
