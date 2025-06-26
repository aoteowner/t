import 'package:nop/utils.dart';

import 'context.dart';
import 'type.dart';

const _w = '[A-Za-z_\\-#0-9\\\\.]+';

final _baseReg = RegExp('($_w) (.*)= ($_w);');
final _sectionReg = RegExp('---(\\w+)---');

void parse(List<String> lines, TgContext context) {
  var section = '';
  for (var line in lines) {
    final sec = _sectionReg.allMatches(line).toList();
    if (sec case [var first]) {
      section = first[1]!;
      continue;
    }

    if (section != 'types') continue;

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

      final hash = nameL.elementAtOrNull(1);

      final fieldSplit = match[2]!.split(' ').where((e) => e.isNotEmpty);
      final fields = <Field>[];
      // Field? _flag;
      for (var span in fieldSplit) {
        final list = span.split(':');
        final name = list.first;
        final second = list.elementAtOrNull(1);
        if (second == null) {
          Log.w('error: field type not found.\n${match[0]}');
          continue;
        }

        final field =
            Field(name: name, type: getBaseTypeFrom(name) ?? int32Type);

        fields.add(field);
        // if (second == '#') {
        //   final flag = Field.flags(flags: [], name: name, type: );
        // }
      }

      final parent = match[3]!;

      final type =
          TgType(baseName: name, hash: hash, fields: fields, parent: parent);
      context.addType(filePrefix, type);
    }
  }
}
