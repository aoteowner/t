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
  final context = TgContext('api');
  for (var file in files) {
    final stringToBytes = file.basename == genFiles.first;
    if (!file.existsSync()) {
      Log.w('file not found: ${file.path}');
      return;
    }
    final lines = file.readAsLinesSync();
    parse(lines, context, stringToBytes);
  }

  final temp =
      fs.currentDirectory.parent.childDirectory('tg_api').childDirectory('lib');
  final src = temp.childDirectory('src');
  context.write(src);
  context.writeReadTlObject(src);

  genExport(src);
  Process.runSync('dart', ['format', '.'], workingDirectory: temp.path);
}
