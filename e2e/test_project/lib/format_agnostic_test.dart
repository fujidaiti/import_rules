// Test file for demonstrating format-agnostic pattern matching
//
// This file tests that patterns in import_rules.yaml can be written using
// either package: URIs or relative paths, and they will match imports
// regardless of the format used.

// Test Case 1: This import should be blocked when the rule uses package: URI pattern
// Expected violation at line 10
// ignore: unused_import
import 'package:test_project/data/repository.dart'; // Should violate

// Test Case 2: This import should also be blocked by the same rule
// Expected violation at line 14
// ignore: duplicate_import, unused_import
import 'data/repository.dart'; // Should also violate

// Test Case 3: Allowed import (not in the disallow list)
// ignore: unused_import
import 'package:test_project/models/user.dart'; // Should be allowed

void main() {
  print('Testing format-agnostic pattern matching');
}
