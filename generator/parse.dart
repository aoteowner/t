import 'package:nop/utils.dart';

import 'context.dart';
import 'type.dart';

const _w = '[A-Za-z_\\-#0-9\\\\.<>]+';

final _baseReg = RegExp('($_w) ({X:Type})?(.*)= ($_w);');
final _sectionReg = RegExp('---(\\w+)---');

final _flagReg = RegExp('($_w)\\.([0-9]+)\\?($_w)');

void parse(List<String> lines, TgContext context, bool stringToBytes) {
  var section = 'types';
  for (var line in lines) {
    final stringOrObject = line.startsWith('//') ? 'TlObject' : 'bytes';

    final sec = _sectionReg.allMatches(line).toList();
    if (sec case [var first]) {
      section = first[1]!;
      continue;
    }

    if (section != 'types' && section != 'functions') continue;

    final matches = _baseReg.allMatches(line);
    for (var match in matches) {
      final nameL = match[1]!.split('#');
      var name = nameL.first;
      final isBaseType = getBaseTypeFrom(name) != null;
      if (isBaseType) {
        continue;
      }

      String? filePrefix;
      final namep = name.split('.');
      if (namep.length == 2) {
        name = namep[1];
        filePrefix = namep[0];
      }

      final hash = nameL.elementAtOrNull(1)?.padLeft(8, '0');

      final fieldSplit = match[3]!.split(' ').where((e) => e.isNotEmpty);
      final fields = <Field>[];
      final flags = <String, Field>{};
      for (var span in fieldSplit) {
        final list = span.split(':');
        final name = list.first;
        final second = list.elementAtOrNull(1);
        if (second == null) {
          Log.w('error: field type not found.\n${match[0]}');
          continue;
        }

        if (second == '#') {
          final f =
              Field.flags(flags: [], name: name, type: PathTy(context, 'int'));
          flags[name] = f;
          fields.add(f);
          continue;
        }

        final flagMatch = _flagReg.allMatches(second).firstOrNull;

        if (flagMatch != null) {
          final flagName = flagMatch[1]!;
          final position = int.parse(flagMatch[2]!);
          var type = flagMatch[3]!;
          if (stringToBytes && name != 'error_message') {
            type = type.replaceAll('string', stringOrObject);
          }

          if (name.endsWith('date')) {
            type = 'DateTime';
          }
          final field = Field(
            name: name,
            type: PathTy(context, type),
            position: position,
            flagName: flagName,
          );
          flags[flagName]?.flags.add((position, field));
          fields.add(field);
        } else {
          var type = second;
          if (stringToBytes && name != 'error_message') {
            type = type.replaceAll('string', stringOrObject);
          }
          if (name.endsWith('date')) {
            type = 'DateTime';
          }
          final field = Field(name: name, type: PathTy(context, type));

          fields.add(field);
        }
      }

      final parent = match[4]!;
      if (section == 'types') {
        final type = TgType(
          baseName: name,
          hash: hash,
          fields: fields,
          parent: parent,
          filePrefix: filePrefix,
        );
        context.addType(filePrefix, type);
      } else {
        final fn = TgFunction(
          retType: PathTy(context, parent),
          baseName: name,
          fields: fields,
          hash: hash,
        );
        context.addFn(filePrefix, fn);
      }
    }
  }
}
