// Test suite A4: src Directory Encapsulation
// This file tests that files can import from their own src/ but not from other module's src/

import 'package:test_project/features/auth/src/utils.dart'; // Allowed (same module)
import 'package:test_project/features/profile/src/helper.dart'; // Should violate (different module)

void useAuth() {
  // Use imports to avoid unused import warnings
  authUtil();
  profileHelper();
}
