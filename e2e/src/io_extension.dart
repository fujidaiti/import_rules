import 'dart:io';

import 'package:path/path.dart' as p;

extension DirectoryExtension on Directory {
  Directory childDirectory(String name) => Directory(p.join(path, name));

  File childFile(String name) => File(p.join(path, name));

  Link childSymlink(String name) => Link(p.join(path, name));

  /// Recursively create subdirectories and files.
  void createFiles(Map<String, Object> fileTree) {
    void visitor(Directory parent, Map<String, Object> fileTree) {
      for (final entry in fileTree.entries) {
        if (entry.value case final String content) {
          parent.childFile(entry.key).writeAsStringSync(content);
        } else if (entry.value case final Map<String, Object> subSources) {
          final subDir = parent.childDirectory(entry.key)..createSync();
          visitor(subDir, subSources);
        } else {
          throw AssertionError(
            'Invalid entry type ${entry.value.runtimeType} '
            'for ${parent.path}/${entry.key}',
          );
        }
      }
    }

    visitor(this, fileTree);
  }
}
