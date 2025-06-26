import 'dart:io';

import 'package:file/local.dart';
import 'package:nop/utils.dart';
import 'package:path/path.dart';

import 'context.dart';
import 'parse.dart';

const fs = LocalFileSystem();

const genFiles = ['mtproto_api.tl', 'secret_api.tl', 'telegram_api.tl'];
void main() async {
  final dir = fs.currentDirectory
      .childDirectory(join('td', 'td', 'generate', 'scheme'));

  final files = genFiles.map((e) => dir.childFile(e)).toList();
  final contexts = <String, TgContext>{};
  for (var file in files) {
    final context = contexts.putIfAbsent(
        file.path, () => TgContext(withoutExtension(file.basename)));
    if (!file.existsSync()) {
      Log.w('file not found: ${file.path}');
      return;
    }
    final lines = file.readAsLinesSync();
    parse(lines, context);
  }

  final temp = fs.currentDirectory.childDirectory('temp');
  for (var context in contexts.values) {
    context.write(temp);
  }
  Process.runSync('dart', ['format', '.'], workingDirectory: temp.path);
}
