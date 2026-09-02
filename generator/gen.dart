import 'dart:io';

import 'package:file/local.dart';
import 'package:nop/utils.dart';
import 'package:path/path.dart';

import 'context.dart';
import 'gen_exp.dart';
import 'parse.dart';

const fs = LocalFileSystem();

const genFiles = ['mtproto_api.tl', 'secret_api.tl', 'telegram_api.tl'];
void main() async {
  final dir = fs.currentDirectory
      .childDirectory(join('td', 'td', 'generate', 'scheme'));

  final files = genFiles.map((e) => dir.childFile(e)).toList();
  // final context = TgContext('tg');
  final contexts = <TgContext>[];
  for (var file in files) {
    final stringToBytes = file.basename == genFiles.first;
    if (!file.existsSync()) {
      Log.w('file not found: ${file.path}');
      return;
    }
    final lines = file.readAsLinesSync();
    final context = TgContext(withoutExtension(file.basename));
    contexts.add(context);
    parse(lines, context, stringToBytes);
  }

  // final temp =
  //     fs.currentDirectory.childDirectory(join('temp', 'test_tg_api')).childDirectory('lib');
  final temp = fs.currentDirectory.parent
      .childDirectory('tg_api2')
      .childDirectory('lib');
  temp.createSync(recursive: true);
  final src = temp.childDirectory('src');
  for (var context in contexts) {
    context.write(src);
  }

  genExport(src);
  for (var context in contexts) {
    context.writeReadTlObject(src);
  }

  Process.runSync('dart', ['format', '.'], workingDirectory: temp.path);
}
