import 'package:file/file.dart';

import 'type.dart';

final _vecReg = RegExp('[Vv]ector<(.*)>');

class TgContext {
  TgContext(this.name);
  final _all = <String, TgType>{};
  final _parents = <String, List<TgType>>{};
  final _children = <String, TgContext>{};
  final _fns = <TgFunction>[];
  final String name;

  Map<String, TgContext> get children => _children;
  Map<String, List<TgType>> get parents => _parents;

  void addType(String? filePrefix, TgType type) {
    var context = this;
    if (filePrefix != null) {
      context = _children.putIfAbsent(filePrefix, () => TgContext(filePrefix));
    }

    context._parents.putIfAbsent(type.parent, () => []).add(type);
    context._all[type.name] = type;
  }

  void addFn(String? filePrefix, TgFunction fn) {
    var context = this;
    if (filePrefix != null) {
      context = _children.putIfAbsent(filePrefix, () => TgContext(filePrefix));
    }

    context._fns.add(fn);
  }

  TgType? _getType(String? prefix, String name) {
    var context = this;
    if (_children[prefix] case var v?) {
      context = v;
    }

    return context._all[name];
  }

  BaseType? getType(String name) {
    final match = _vecReg.allMatches(name).firstOrNull;
    var isList = false;
    if (match != null) {
      isList = true;
      name = match[1]!;
    }
    final list = name.split('.');
    String? prefix;
    if (list.length == 2) {
      prefix = list[0];
      name = list[1];
    }
    name = name.dartClassName;

    final type = _getType(prefix, name);
    final t = type ?? Constructor(name: name, prefix: prefix);
    if (isList) {
      return VectorObjectType(t);
    }
    return t;
  }

  void write(Directory dir, {int level = 0}) {
    final nextDir = dir.childDirectory(name);
    final temp = StringBuffer();
    final list = <String>[];

    for (var entry in _parents.entries) {
      _writeList(nextDir, entry.key, entry.value, temp, level, list);
    }

    if (_fns.isNotEmpty || temp.isNotEmpty) {
      final buffer = StringBuffer();
      buffer.writeln("import 'package:t/base.dart';");
      for (var fn in _fns) {
        fn.getAllImports(level, name, list);
        temp.writeln(fn.code);
      }

      buffer.writeAll(list.toSet());
      buffer.write(temp);

      final file = nextDir.childFile('$name.dart');
      file.createSync(recursive: true);
      file.writeAsStringSync(buffer.toString());
    }

    for (var child in _children.values) {
      child.write(nextDir, level: level + 1);
    }
  }

  void _writeList(Directory dir, String base, List<TgType> list,
      StringBuffer fBuffer, int level, List<String> importsE) {
    base = base.split('.').last;

    final buffer = StringBuffer();

    var parent = 'TlConstructor';

    final imports = <String>[];
    final baseClassName = base.dartClassName;
    if (list.length > 1 || (list.isNotEmpty && list[0].name != baseClassName)) {
      final sameName = list.any((e) => e.name == base);
      final name = sameName ? '${baseClassName}Base' : baseClassName;
      buffer.write('''
sealed class $name extends $parent {
const $name();
}

''');
      parent = name;
    }

    for (var t in list) {
      t.getAllImports(level, name, imports);
      buffer.write('''class ${t.name} extends $parent {
const ${t.name}(${t.fields.argsCode});
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

    final n = base.dartFileName;

    if (n == name.dartFileName) {
      importsE.addAll(imports);
      fBuffer.write(buffer);
      return;
    }

    final b = StringBuffer();
    b.writeln("import 'package:t/base.dart';");
    b.writeAll(imports.toSet());
    b.write(buffer);

    final file = dir.childFile('$n.dart');
    file.createSync(recursive: true);
    file.writeAsStringSync(b.toString());
  }
}
