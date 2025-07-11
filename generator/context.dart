import 'package:collection/collection.dart';
import 'package:file/file.dart';
import 'package:nop/utils.dart';
import 'package:path/path.dart';

import 'type.dart';

final _vecReg = RegExp('[Vv]ector<(.*)>');
final _vecCReg = RegExp('[Vv]ector<%(.*)>');

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

    final list = context._parents.putIfAbsent(type.parent, () => []);
    final same = list.firstWhereOrNull((e) => e.name == type.name);
    if (same != null) {
      if (same.hash == type.hash) {
        return;
      }

      type.useHash = 'Hash${type.hash}';
    }

    list.add(type);
    type.parents = list;
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

  Iterable<TgFunction> get availableFns => _fns.where((e) => e.hash != null);

  BaseType? getType(String name) {
    var match = _vecCReg.allMatches(name).firstOrNull;
    final isC = match != null;
    match ??= _vecReg.allMatches(name).firstOrNull;

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

    final type = getBaseTypeFrom(name) ?? _getType(prefix, name);
    final t = type ?? Constructor(name: name, prefix: prefix);
    if (isList) {
      return VectorObjectType(t, isC);
    }
    return t;
  }

  void write(Directory dir,
      {int level = 0, bool hasClient = true, String? baseName}) {
    final nextDir = dir.childDirectory(name);
    final buffer = StringBuffer();
    baseName ??= name;
    final temp = StringBuffer();
    final clients = StringBuffer();

    for (var child in _children.values) {
      child.write(nextDir,
          hasClient: _fns.isNotEmpty, level: level + 1, baseName: baseName);
      if (child.availableFns.isNotEmpty) {
        final name = child.name;
        buffer.writeln(
            'import "${name.dartFileName}/${name.dartFileName}.dart" as \$${name.dartMemberName};');
        clients.writeln(
            'late final  ${name.dartMemberName}Api = \$${name.dartMemberName}.${name.dartClassName}Client(this);');
      }
    }

    final list = <String>[];

    for (var entry in _parents.entries) {
      _writeList(nextDir, entry.key, entry.value, temp, level, list);
    }

    if (availableFns.isNotEmpty || temp.isNotEmpty) {
      if (name.dartClassName == 'Test') {
        Log.w(
            '....${_fns.map((e) => e.baseName).logPretty()} ${temp.isNotEmpty}');
      }
      final fnsMethod = StringBuffer();

      if (level == 0 || !hasClient) {
        temp.write('abstract mixin ');
      }

      temp.write('''
class ${name.dartClassName}Client {
$clients
''');

      if (level == 0) {
        temp.write('''
Future<Result<TlObject>> invoke(TlMethod method);

''');
      } else if (hasClient) {
        final p = '../' * level;
        buffer.writeln('import "$p${baseName.dartFileName}.dart";');
        temp.write('''
const ${name.dartClassName}Client(this.client);
final ${baseName.dartClassName}Client client;
''');
      }

      for (var fn in _fns) {
        if (fn.hash != null) {
          fnsMethod.writeln(fn.methodCode);
          fn.getAllImports(level, name, list);
          temp.writeln(fn.code(level == 0 ? '' : 'client.'));
        }
      }

      temp.write('}');

      if (fnsMethod.isNotEmpty) {
        final p = '../' * (level +1);
        buffer.writeln("import '${p}base.dart';");
      }

      buffer.writeAll(list.toSet());

      buffer.write(fnsMethod);

      buffer.write(temp);

      final file = nextDir.childFile('$name.dart');
      file.createSync(recursive: true);
      file.writeAsStringSync(buffer.toString());
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
      buffer.write('''
/// ${t.hash}
class ${t.name} extends $parent {
const ${t.name}(${t.fields.argsCode});
${t.fields.defineCode}

  factory ${t.name}.deserialize(BinaryReader reader) {
  ${t.fields.readCode}

    return ${t.name}(${t.fields.named});
  }
  @override
  void serialize(List<int> buffer) {
    buffer.writeInt32(0x${t.hash ?? '0'});
  ${t.fields.writeCode}
  }
  
  @override
  Map<String, dynamic> toJson() {
    return {
      ${t.hash == null ? '' : '"\\\$hash": "${t.hash}",'}
      "\\\$name": "${t.name}",
      ${t.fields.jsonCode}
    };
  }
  @override
  List<Object?> get props => ${t.fields.propsCode};
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
    final p = '../' * (level + 1);
    b.writeln("import '${p}base.dart';");
    b.writeAll(imports.toSet());
    b.write(buffer);

    final file = dir.childFile('$n.dart');
    file.createSync(recursive: true);
    file.writeAsStringSync(b.toString());
  }

  void writeReadTlObject(Directory dir) {
    final file = dir.childFile('${name}_read.dart');
    file.createSync(recursive: true);
    final buf = StringBuffer();

    final fnBuffer = StringBuffer();

    for (var all in _parents.entries) {
      for (var type in all.value) {
        if (type.hash == null) continue;
        buf.writeln('0x${type.hash} => ${type.className}.deserialize(reader),');
      }
    }

    for (var fn in _fns) {
      if (fn.hash == null) continue;
      fnBuffer.writeln(
          '0x${fn.hash} => \$e.${fn.baseName.dartClassName}Method.deserialize(reader),');
    }

    for (var child in _children.values) {
      for (var all in child._parents.entries) {
        for (var type in all.value) {
          if (type.hash == null) continue;

          buf.writeln(
              '0x${type.hash} => ${type.className}.deserialize(reader),');
        }
      }
      for (var fn in child._fns) {
        if (fn.hash == null) continue;
        fnBuffer.writeln(
            '0x${fn.hash} => \$${child.name.dartMemberName}.${fn.baseName.dartClassName}Method.deserialize(reader),');
      }
    }

    final buffer = StringBuffer();

    final list = dir.parent.listSync(recursive: false);
    for (var file in list) {
      if (file case File file) {
        final n = withoutExtension(file.basename);

        if (n == name) {
          buffer.writeln('import "../${file.basename}" as \$e;');
          continue;
        }

        if (_children[n] case var v
            when v == null ||
                (v._all.isEmpty && v._fns.every((e) => e.hash == null))) {
          continue;
        }
        buffer.writeln(
            'import "../${file.basename}" as \$${withoutExtension(file.basename)};');
      }
    }

    buffer.write('''
import "base/binary_reader.dart";
import "base/core.dart";

TlObject readTlObject(BinaryReader reader) {
  final id = reader.readInt32();


  final value = switch(id) {
  vectorCtor => reader.readVectorObjectNoCtor(),
  $buf
  _ => null,
  };

  if (value != null) return value;
  /// method
  return switch(id) {
  $fnBuffer
  _ => throw Exception(
      'id: \${id.toRadixString(16)}. This is a bug. Please report at https://github.com/telegramflutter/tg/issues.'),
  };
}
''');

    file.writeAsStringSync(buffer.toString());
  }
}
