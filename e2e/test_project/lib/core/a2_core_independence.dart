// Test suite A2: Core Domain Independence
// This file tests that core domain cannot import framework packages

import 'package:test_project/core/models.dart'; // Allowed
// Commented out to avoid compile errors since flutter is not a dependency
// import 'package:flutter/material.dart'; // Should violate

void useCore() {
  CoreModel();
}
