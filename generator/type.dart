import 'package:characters/characters.dart';

abstract class BaseType {
  String readerCode(String name);
  String writerCode(String name);
  String toJsonCode(String name);

  String get className;

  String defineCode(String name) {
    return 'final $className $name';
  }
}

final class LabelType extends BaseType {
  LabelType._(this.label, this.className) : writeLabel = label;
  LabelType._write(this.label, this.writeLabel, this.className);
  final String label;
  final String writeLabel;
  @override
  final String className;

  @override
  String readerCode(String name) => 'reader.read$label()';

  @override
  String toJsonCode(String name) => name;

  @override
  String writerCode(String name) => 'buffer.write$writeLabel($name)';
}

final int32Type = LabelType._('Int32', 'int');
final int64Type = LabelType._('Int64', 'int');
final int128Type = LabelType._('Int128', 'Int128');
final int256Type = LabelType._('Int256', 'Int256');
final stringType = LabelType._('String', 'String');
final float64Type = LabelType._write('Float64', 'Double', 'double');
final boolType = LabelType._('Bool', 'bool');
final dateTimeType = LabelType._('DateTime', 'DateTime');
final bytesType = LabelType._('Bytes', 'Uint8List');
final vectorInt32Type = LabelType._('VectorInt32', 'List<int>');
final vectorInt64Type = LabelType._('VectorInt64', 'List<int>');
final vectorStringType = LabelType._('VectorString', 'List<String>');
final vectorBytesType = LabelType._('VectorBytes', 'List<Uint8List>');

BaseType? getBaseTypeFrom(String type) {
  return switch (type) {
    'Int' || 'int' || 'Long' || 'long' => int32Type,
    'Double' || 'double' => float64Type,
    'String' || 'string' => stringType,
    'Bytes' || 'bytes' => bytesType,
    'int256' || 'Int256' => int256Type,
    'true' || 'True ' || 'boolFalse' || 'boolTrue' || 'Bool' => boolType,
    _ => null,
  };
}

class VectorObjectType extends BaseType {
  VectorObjectType(this.childType);

  final TgType childType;
  @override
  String get className => 'List<${childType.className}>';
  @override
  String readerCode(String name) {
    return 'reader.readVectorObject<${childType._className}>()';
  }

  @override
  String toJsonCode(String name) {
    return name;
  }

  @override
  String writerCode(String name) {
    return 'buffer.writeVectorObject($name)';
  }
}

class TgType extends BaseType {
  TgType({
    required this.baseName,
    this.hash,
    required this.fields,
    required this.parent,
  });

  final String parent;
  final String baseName;
  final String? hash;
  final List<Field> fields;

  late final _className =
      baseName.replaceFirst(baseName[0], baseName[0].toUpperCase());

  @override
  String get className => _className;

  @override
  String readerCode(String name) {
    return 'reader.readObject() as $className';
  }

  @override
  String toJsonCode(String name) {
    return '$name.toJson()';
  }

  @override
  String writerCode(String name) {
    return 'buffer.writeObject()';
  }
}

const _keys = ['default', 'final'];

String _fieldName(String name) {
  if (_keys.contains(name)) {
    return 'd$name';
  }

  return name;
}

class Field {
  Field({required String name, required this.type})
      : name = _fieldName(name.dartMemberName),
        flags = const [];
  Field.flags({
    required this.flags,
    required this.name,
    required this.type,
  });
  final String name;
  final BaseType type;
  final List<(int, Field)> flags;

  String argCode() {
    return 'required this.$name';
  }

  String defineCode() {
    return type.defineCode(name);
  }

  String toJsonCode() {
    return type.toJsonCode(name);
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
  final BaseType retType;

  String get code {
    return '''
Future<Result<${retType.className}>> $baseName({
${fields.map((e) => e.argCode()).join(',')}
}) {


}
''';
  }
}

extension on String {
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
}
