// Test suite A5: Test Isolation
// Unit tests should not import integration test utilities

import 'package:test/test.dart';
import 'package:test_project/core/models.dart'; // Allowed - lib code

// This should violate - unit tests importing integration test utilities
import '../integration/helpers.dart'; // Should violate

void main() {
  test('unit test', () {
    expect(CoreModel(), isNotNull);
    integrationTestHelper(); // Use the import to avoid unused warning
  });
}
