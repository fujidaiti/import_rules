import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('import_rules.schema.json is valid and defines required fields', () {
    final file = File('import_rules.schema.json');
    expect(file.existsSync(), isTrue);

    final schema = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(schema['type'], equals('object'));
    expect(schema['required'], contains('rules'));

    final properties = schema['properties'] as Map<String, dynamic>;
    expect(properties.containsKey('rules'), isTrue);
    expect(properties.containsKey('severity'), isTrue);
  });
}
