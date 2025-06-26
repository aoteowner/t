import 'package:characters/characters.dart';
import 'package:file/file.dart';

import 'type.dart';

class TgContext {
  TgContext(this.name);
  final _parents = <String, List<TgType>>{};
  final _children = <String, TgContext>{};
  final String name;

  Map<String, TgContext> get children => _children;
  Map<String, List<TgType>> get parents => _parents;

  void addType(String? filePrefix, TgType type) {
    var context = this;
    if (filePrefix != null) {
      context = _children.putIfAbsent(filePrefix, () => TgContext(filePrefix));
    }

    context._parents.putIfAbsent(type.parent, () => []).add(type);
  }

  void write(Directory dir) {
    final nextDir = dir.childDirectory(name);
    for (var entry in _parents.entries) {
      _writeList(nextDir, entry.key, entry.value);
    }

    for (var child in _children.values) {
      child.write(nextDir);
    }
  }

  void _writeList(Directory dir, String base, List<TgType> list) {
    base = base.split('.').last;

    final file = dir.childFile('${base.dartFileName}.dart');
    final buffer = StringBuffer();
    buffer.writeln("import 'dart:typed_data';");
    buffer.writeln("import 'package:t/t.dart';");
    var parent = 'TlConstructor';

    if (list.length != 1) {
      final sameName = list.any((e) => e.className == base);
      final name = sameName ? '${base}Base' : base;
      buffer.write('''
sealed class $name extends $parent {
const $name();
}

''');
      parent = name;
    }

    for (var t in list) {
      buffer.write('''class ${t.className} extends $parent {
const ${t.className}(${t.fields.argsCode});
${t.fields.defineCode}
  @override
  void serialize(List<int> buffer) {
  }
  
  @override
  Map<String, dynamic> toJson() {
    return {
      ${t.fields.jsonCode}
    };
  }
}
''');
    }
    file.createSync(recursive: true);
    file.writeAsStringSync(buffer.toString());
  }
}

extension on List<Field> {
  String get argsCode {
    final buffer = StringBuffer();
    for (var field in this) {
      buffer.write(field.argCode());
      buffer.write(',');
    }
    if (buffer.isNotEmpty) {
      return '{$buffer}';
    }

    return buffer.toString();
  }

  String get defineCode {
    final buffer = StringBuffer();
    for (var field in this) {
      buffer.write(field.defineCode());
      buffer.writeln(';');
    }

    return buffer.toString();
  }

  String get jsonCode {
    final buffer = StringBuffer();
    for (var field in this) {
      buffer.write('"');
      buffer.write(field.name);
      buffer.write('": ');
      buffer.write(field.toJsonCode());
      buffer.writeln(',');
    }

    return buffer.toString();
  }
}

final _upperReg = RegExp('[A-Z]');

extension on String {
  String get dartFileName {
    final buffer = StringBuffer();
    final pc = characters.iterator;

    while (pc.moveNext()) {
      final current = pc.current;
      if (buffer.isEmpty) {
        buffer.write(current.toLowerCase());
        continue;
      }

      if (_upperReg.hasMatch(current)) {
        buffer.write('_');
        buffer.write(current.toLowerCase());
        continue;
      }

      buffer.write(current);
    }

    return buffer.toString();
  }
}
