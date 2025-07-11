import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart';

const fs = LocalFileSystem();

void genExport(Directory src) {
  final all = src.listSync(recursive: false);
  final map = <String, List<String>>{};

  void genExports(Directory dir) {
    final files = dir.listSync(recursive: false);

    for (var file in files) {
      if (file case Directory dir) {
        if (dir.basename.endsWith('_e')) continue;
        genExports(dir);
        continue;
      }
      if (file case File file) {
        map.putIfAbsent(dir.path, () => []).add(file.path);
      }
    }
  }

  for (var file in all) {
    if (file case Directory dir) {
      if (basename(dir.path) == 'base') continue;
      genExports(dir);
    }
  }

  final parent = src.parent;
  for (var entry in map.entries) {
    final name = entry.key;
    final files = entry.value;
    final current = parent.childFile('${basename(name)}.dart');
    current.createSync(recursive: true);
    final buf = StringBuffer();
    buf.writeln('export "dart:typed_data";');
    for (var file in files) {
      final relativeName = relative(file, from: parent.path);
      buf.writeln('export "${relativeName.replaceAll('\\', '/')}";');
    }
    current.writeAsStringSync(buf.toString());
  }
}
