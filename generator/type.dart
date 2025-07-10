import 'package:characters/characters.dart';

import 'context.dart';

abstract class BaseType {
  String readerCode(String name);
  String writerCode(String name);
  String toJsonCode(String name, {String optional = ''});

  String get className;

  String get defineType => className;
  String importPath(int level, String prefix) => '';

  String defineCode(String name, {String optional = ''}) {
    return 'final $defineType$optional $name';
  }

  bool get isBool => false;
}

final class LabelType extends BaseType {
  LabelType._(this.label, this.className,
      {String? defineType,
      this.suf = '',
      this.imports = '',
      this.jsonValue = '',
      this.isBool = false})
      : writeLabel = label,
        _defineType = defineType;
  LabelType._write(this.label, this.writeLabel, this.className,
      {String? defineType})
      : imports = '',
        suf = '',
        isBool = false,
        jsonValue = '',
        _defineType = defineType;
  final String label;
  final String writeLabel;
  @override
  final String className;

  final String? _defineType;
  final String jsonValue;

  final String suf;
  @override
  final bool isBool;
  @override
  String get defineType => _defineType ?? className;
  final String imports;
  @override
  String importPath(int level, String prefix) {
    return imports;
  }

  @override
  String readerCode(String name) => 'reader.read$label()$suf';

  @override
  String toJsonCode(String name, {String optional = ''}) {
    if (jsonValue.isNotEmpty) {
      return '$name$optional$jsonValue';
    }
    return name;
  }

  @override
  String writerCode(String name) => 'buffer.write$writeLabel($name)';
}

final int32Type = LabelType._('Int32', 'int');
final int64Type = LabelType._('Int64', 'int');
final int128Type = LabelType._('Int128', 'Int128');
final int256Type = LabelType._('Int256', 'Int256');
final stringType = LabelType._('String', 'String');
final float64Type = LabelType._write('Float64', 'Double', 'double');

final boolType =
    LabelType._('Bool', 'Boolean', defineType: "bool", isBool: true);
final trueType =
    LabelType._('Bool', 'Boolean', defineType: "bool", isBool: true);
final boolFalseType =
    LabelType._('Bool', 'Boolean', defineType: "bool", isBool: true);

final dateTimeType =
    LabelType._('DateTime', 'DateTime', jsonValue: '.millisecondsSinceEpoch');
final bytesType = LabelType._(
  'Bytes',
  'Uint8List',
  imports: "import 'dart:typed_data';",
);
final vectorInt32Type = LabelType._('VectorInt32', 'List<int>', suf: '.items');
final vectorInt64Type = LabelType._('VectorInt64', 'List<int>', suf: '.items');
final vectorStringType =
    LabelType._('VectorString', 'List<String>', suf: '.items');
final vectorBytesType = LabelType._(
  'VectorBytes',
  'List<Uint8List>',
  imports: "import 'dart:typed_data';",
  suf: '.items',
);
final tlObjectType = LabelType._('Object', 'TlObject');
final tlObjectdType = LabelType._('Object', 'TlMethod', suf: 'as TlMethod');

final _vecReg = RegExp('[Vv]ector<(.*)>');
BaseType? getBaseTypeFrom(String type) {
  final t = switch (type) {
    'Int' || 'int' => int32Type,
    'Long' || 'long' => int64Type,
    'Double' || 'double' => float64Type,
    'String' || 'string' => stringType,
    'Bytes' || 'bytes' => bytesType,
    'int256' || 'Int256' => int256Type,
    'int128' || 'Int128' => int128Type,
    'true' || 'True ' || 'boolTrue' => trueType,
    'boolFalse' => boolFalseType,
    'Bool' => boolType,
    "X" || "TlObject" => tlObjectType,
    "DateTime" => dateTimeType,
    "!X" => tlObjectdType,
    _ => null,
  };
  if (t != null) return t;
  final match = _vecReg.allMatches(type).firstOrNull;
  if (match != null) {
    final name = getBaseTypeFrom(match[1]!);
    if (name == int32Type) {
      return vectorInt32Type;
    } else if (name == int64Type) {
      return vectorInt64Type;
    } else if (name == stringType) {
      return vectorStringType;
    } else if (name == bytesType) {
      return vectorBytesType;
    }
  }

  return null;
}

class Constructor extends BaseType {
  Constructor({required this.name, this.prefix});
  final String name;
  final String? prefix;
  @override
  String get className {
    final prefix = this.prefix ?? 'e';
    return '\$$prefix.$name';
  }

  @override
  String get defineType {
    return '${className}Base';
  }

  @override
  String importPath(int level, String prefix) {
    var pre = '';
    final filePrefix = this.prefix;
    if (filePrefix == prefix) {
      level -= 1;
    } else if (filePrefix != null) {
      pre = '$filePrefix/';
    }

    var asPre = 'as \$${filePrefix ?? 'e'}';
    if (level < 0) {
      level = 0;
    }

    final p = '../' * level;
    return 'import "$p$pre${name.dartFileName}_e.dart"$asPre;';
  }

  @override
  String readerCode(String name) => 'reader.readObject() as $defineType';

  @override
  String toJsonCode(String name, {String optional = ''}) => name;

  @override
  String writerCode(String name) => 'buffer.writeObject($name)';
}

class VectorObjectType extends BaseType {
  VectorObjectType(this.childType, [this.isC = false]);

  final BaseType childType;
  final bool isC;

  @override
  String get className => 'List<${childType.className}>';

  @override
  String importPath(int level, String prefix) {
    return childType.importPath(level, prefix);
  }

  @override
  String get defineType {
    return 'List<${childType.defineType}>';
  }

  @override
  String readerCode(String name) {
    if (isC) {
      return '''reader.readVectorObjectFn<${childType.defineType}>((reader) {
    return ${childType.className}.deserialize(reader);
    }).items''';
    }
    return 'reader.readVectorObject<${childType.defineType}>().items';
  }

  @override
  String toJsonCode(String name, {String optional = ''}) {
    if (childType case TgType()) {
      return '$name$optional.map((e) => e.toJson()).toList()';
    }
    return name;
  }

  @override
  String writerCode(String name) {
    if (isC) {
      return 'buffer.writeVectorObjectNoCtor($name)';
    }
    return 'buffer.writeVectorObject($name)';
  }
}

class TgType extends BaseType {
  TgType({
    required String baseName,
    this.hash,
    required this.fields,
    required this.parent,
    this.filePrefix,
  }) : baseName = baseName.dartClassName;

  final String parent;
  final String baseName;
  final String? hash;
  final List<Field> fields;
  final String? filePrefix;
  List<TgType>? parents;

  String useHash = '';

  @override
  String importPath(int level, String prefix) {
    var pre = '';
    if (filePrefix == prefix) {
      level -= 1;
    } else if (filePrefix != null) {
      pre = '$filePrefix/';
    }

    var asPre = 'as \$${filePrefix ?? 'e'}';

    if (level < 0) {
      level = 0;
    }

    final p = '../' * level;
    return 'import "$p$pre${baseName.dartFileName}_e.dart"$asPre;';
  }

  void getAllImports(int level, String prefix, List<String> buffer) {
    for (var field in fields) {
      field.getAllImports(level, prefix, buffer);
    }
  }

  late final _className =
      baseName.replaceFirst(baseName[0], baseName[0].toUpperCase());

  String get name => '$_className$useHash';

  String get nameHash => '${_className}Hash_${hash ?? ''}';

  @override
  String get defineType {
    // if (parents case var list? when list.isNotEmpty) {
    //   // if (parent.split('.').last == 'Message') {
    //   //  Log.w('.....${list}');
    //   // }
    //   if (list.length > 1 ||
    //       (list.isNotEmpty &&
    //           list[0].name != parent.split('.').last.dartClassName)) {
    //     return '$className${useHash}Base';
    //   }
    // }
    // return "$className$useHash";
    return '$className${useHash}Base';
  }

  @override
  String get className {
    final prefix = filePrefix ?? 'e';
    return '\$$prefix.$_className$useHash';
  }

  @override
  String readerCode(String name) {
    return 'reader.readObject() as $defineType';
  }

  @override
  String toJsonCode(String name, {String optional = ''}) {
    return '$name$optional.toJson()';
  }

  @override
  String writerCode(String name) {
    return 'buffer.writeObject($name)';
  }
}

const _keys = ['default', 'final', 'int', 'bool', 'double', 'string'];

String _fieldName(String name) {
  if (_keys.contains(name)) {
    return 'd$name';
  }

  return name;
}

class Field {
  Field(
      {required String name,
      required this.type,
      this.position = -1,
      this.flagName = ''})
      : name = _fieldName(name.dartMemberName),
        flags = const [];
  Field.flags({
    required this.flags,
    required this.name,
    required this.type,
  })  : position = -1,
        flagName = '';
  final String name;
  final PathTy type;
  final List<(int, Field)> flags;

  final int position;
  final String flagName;

  String argCode() {
    if (flags.isNotEmpty) return '';
    var suf = '';
    var req = 'required ';
    if (position != -1) {
      req = '';
      if (type.type == trueType) {
        suf = ' = false';
      }
    }
    return '$req this.$name$suf,';
  }

  bool get isOptional => position != -1 && type.type != trueType;

  String argFnCode() {
    if (flags.isNotEmpty) return '';
    var suf = '';
    var req = 'required ';
    var optinal = '';
    if (position != -1) {
      optinal = '?';
      req = '';
      if (type.type == trueType) {
        optinal = '';
        suf = ' = false';
      }
    }
    return '$req ${type.defineType}$optinal $name$suf,';
  }

  String defineCode() {
    if (flags.isNotEmpty) {
      final map = <int, List<String>>{};
      for (var f in flags) {
        var v = f.$2.name;
        final t = f.$2.type.type;

        if (t?.isBool == true) {
          if (t != trueType) {
            v = '$v == true';
          }
        } else {
          v = '$v != null';
        }
        map.putIfAbsent(f.$1, () => []).add(v);
      }
      final args = map.entries
          .map((e) =>
              'b${e.key.toString().padLeft(2, '0')}: ${e.value.join('||')},')
          .join();
      return '''
int get ${name.dartMemberName} {
return toFlag(
$args
);


}

''';
    }
    var optional = '';

    if (isOptional) {
      optional = '?';
    }

    final v = type.type?.defineCode(name, optional: optional) ?? '';

    return '$v;';
  }

  String toJsonCode() {
    var optional = '';

    if (isOptional) {
      optional = '?';
    }

    final v = type.type?.toJsonCode(name, optional: optional) ?? '';
    return '$v,';
  }

  String readCode() {
    if (position == -1) {
      final right = type.type?.readerCode(name) ?? '';
      return 'final $name = $right;';
    }
    final mask = 1 << position;
    if (type.type == trueType) {
      final mask = 1 << position;
      return 'final $name = ($flagName & $mask) != 0;';
    }
    final has = 'has${name.dartClassName}Flag';
    return '''
final $has =  ($flagName & $mask) != 0;
final $name = $has ? ${type.type?.readerCode(name)} : null;
''';
  }

  String writeCode() {
    final code = type.type?.writerCode(name) ?? '';
    if (position == -1) {
      return '$code;';
    }

    if (type.type == trueType) {
      return '';
    }
    if (type.type?.isBool == true) {
      return '''
if ($name case var $name? when $name) {
$code;
}

''';
    }
    return '''
if ($name case var $name?) {
$code;
}
''';
  }

  void getAllImports(int level, String prefix, List<String> buffer) {
    if (type.type case var type?) {
      buffer.add(type.importPath(level, prefix));
    }
  }
}

final class PathTy {
  PathTy(this.context, this.name);
  final TgContext context;
  final String name;

  BaseType? _type;

  BaseType? get type {
    if (_type != null) return _type;
    return _type = getBaseTypeFrom(name) ?? context.getType(name);
  }

  String get className {
    return type?.className ?? '';
  }

  String get defineType {
    return type?.defineType ?? '';
  }
}

class TgFunction {
  TgFunction({
    required this.retType,
    required this.baseName,
    required this.fields,
    this.hash,
  });
  final String baseName;
  final String? hash;
  final List<Field> fields;
  final PathTy retType;

  void getAllImports(int level, String prefix, List<String> buffer) {
    final type = retType.type;
    if (type != null) {
      buffer.add(type.importPath(level, prefix));
    }

    for (var field in fields) {
      field.getAllImports(level, prefix, buffer);
    }
  }

  String get abstractCode {
    return '''
Future<Result<${retType.className.replaceAll('List<', 'Vector<')}>> ${baseName.dartMemberName}(${fields.argFnCode});
''';
  }

  String get methodCode {
    return '''
final class ${baseName.dartClassName}Method extends TlMethod {
const ${baseName.dartClassName}Method(${fields.argsCode});
${fields.defineCode}

  factory ${baseName.dartClassName}Method.deserialize(BinaryReader reader) {
  ${fields.readCode}
    return ${baseName.dartClassName}Method(${fields.named});
  }
  @override
  void serialize(List<int> buffer) {
  buffer.writeInt32(0x${hash ?? '0'});
  ${fields.writeCode}
  }
  
  @override
  Map<String, dynamic> toJson() {
    return {
      "\\\$hash": "${hash ?? '0'}",
      "\\\$name": "${baseName.dartClassName}",
      ${fields.jsonCode}
    };
  }

  @override
  List<Object?> get props => ${fields.propsCode};
}
''';
  }

  String code(String client) {
    var ret = retType.defineType.replaceAll('List<', 'Vector<').replaceAll('bool', 'Boolean');

    if (retType.type case TgType t) {
      ret = t.defineType;
    } 

//     if (baseName == 'initConnection') {
//       return '''
// /// $hash
// Future<Result<$ret>> ${baseName.dartMemberName}(${fields.argFnCode}) {
//    return ${client}invokeWithLayer(
//    layer: layer,
//    query: ${baseName.dartClassName}Method(${fields.named}),
//    );
// }
// ''';
//     }

    if (ret == 'TlObject') {
      return '''
/// $hash
Future<Result<$ret>> ${baseName.dartMemberName}(${fields.argFnCode}) {
   return ${client}invoke(${baseName.dartClassName}Method(${fields.named}));

}
''';
    }

    var res = 'to<$ret>()';

    if (retType.type case VectorObjectType t) {
      ret = 'Vector<${t.childType.defineType}>';
      res = 'toVector<${t.childType.defineType}>()';
    }

    return '''
/// $hash
Future<Result<$ret>> ${baseName.dartMemberName}(${fields.argFnCode}) async {
  final res = await ${client}invoke(${baseName.dartClassName}Method(${fields.named}));

  return res.$res;
}
''';
  }
}

final _upperReg = RegExp('[A-Z]');

extension StringExt on String {
  String get dartFileName {
    final buffer = StringBuffer();
    final pc = characters.iterator;

    var islow = false;
    while (pc.moveNext()) {
      final current = pc.current;

      if (buffer.isEmpty) {
        islow = current == '_';
        buffer.write(current.toLowerCase());
        continue;
      }

      if (_upperReg.hasMatch(current)) {
        if (!islow) {
          buffer.write('_');
        }
        islow = false;
        buffer.write(current.toLowerCase());
        continue;
      }

      islow = current == '_';
      buffer.write(current);
    }

    return buffer.toString();
  }

  String get dartMemberName {
    final buffer = StringBuffer();
    final pc = characters.iterator;
    var shouldUpper = false;
    while (pc.moveNext()) {
      final current = pc.current;
      if (current == '_') {
        shouldUpper = true;
        continue;
      }

      if (buffer.isEmpty) {
        buffer.write(current.toLowerCase());
        shouldUpper = false;
        continue;
      }

      if (shouldUpper) {
        buffer.write(current.toUpperCase());
        shouldUpper = false;
        continue;
      }

      buffer.write(current);
    }

    return buffer.toString();
  }

  String get dartClassName {
    final buffer = StringBuffer();
    final pc = characters.iterator;
    var shouldUpper = false;

    while (pc.moveNext()) {
      final current = pc.current;
      if (current == '_') {
        shouldUpper = true;
        continue;
      }

      if (buffer.isEmpty) {
        buffer.write(current.toUpperCase());
        shouldUpper = false;
        continue;
      }

      if (shouldUpper) {
        buffer.write(current.toUpperCase());
        shouldUpper = false;
        continue;
      }

      buffer.write(current);
    }

    return buffer.toString();
  }
}

extension ListFieldExt on List<Field> {
  String get argsCode {
    final buffer = StringBuffer();
    for (var field in this) {
      buffer.write(field.argCode());
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
    }

    return buffer.toString();
  }

  String get readCode {
    final buffer = StringBuffer();
    for (var field in this) {
      buffer.writeln(field.readCode());
    }

    return buffer.toString();
  }

  String get named {
    final buffer = StringBuffer();
    for (var field in this) {
      if (field.flags.isNotEmpty) continue;
      buffer.write(field.name);
      buffer.write(': ');
      buffer.write(field.name);
      buffer.writeln(',');
    }

    return buffer.toString();
  }

  String get writeCode {
    final buffer = StringBuffer();
    for (var field in this) {
      buffer.writeln(field.writeCode());
    }

    return buffer.toString();
  }

  String get argFnCode {
    if (isEmpty) return '';
    return '{${map((e) => e.argFnCode()).join()}}';
  }

  String get propsCode {
    if (isEmpty) return '[]';

    return '[${map((e) => e.name).join(",")}]';
  }
}
