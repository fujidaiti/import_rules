// Test suite A2: Core Domain Independence
// This file tests that core domain cannot import framework packages

import 'package:test_project/core/models.dart'; // Allowed
// Commented out to avoid compile errors since flutter is not a dependency
// import 'package:flutter/material.dart'; // Should violate

void useCore() {
  CoreModel();
}

final project = {
  'lib': {
    'utils': {
      'utils.dart': '''
        import 'package:test_project/core/models.dart';
        import 'dart:math';
        import 'models.dart';
        
        class CoreUtils {
          CoreUtils();
        }
      ''',
    },
    'core': {
      'models.dart': '''
        class CoreModel {
          CoreModel();
        }
      ''',
      'utils.dart': '''
        import 'package:test_project/core/models.dart';
        import 'dart:math';
        import 'models.dart';
        import '../utils/utils.dart';
        
        class CoreUtils {
          CoreUtils();
        }
      ''',
    },
  },
};
