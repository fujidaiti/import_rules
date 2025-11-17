// Test suite: File path patterns
// Tests using lib/** patterns instead of package:** patterns
// This currently doesn't work but should be supported in the future

import 'package:test_project/presentation/widget.dart'; // Should violate with lib/** pattern

void useData() {
  Widget();
}
