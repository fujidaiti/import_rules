// Test suite A1: Layer Architecture Enforcement
// This file tests that presentation layer cannot directly import data layer

import 'package:test_project/data/repository.dart'; // Should violate
import 'package:test_project/data/models/user.dart'; // Should be allowed (exclude_disallow)

void usePresentation() {
  // Use imports to avoid unused import warnings
  Repository();
  User();
}
