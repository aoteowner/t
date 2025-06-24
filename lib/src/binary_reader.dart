import 'dart:convert';
import 'dart:typed_data';

import 'package:t/src/core.dart';
import 'package:t/src/g/binary_reader_object.dart';

/// Read binary data and advance the position.
class BinaryReader {
  /// Constructs a new binary reader.
  BinaryReader(this.buffer);

  /// Buffer.
  final Uint8List buffer;
  int _position = 0;

  /// Gets the position.
  int get position => _position;

  Uint8List _next(int size) {
    final start = position;
    _position += size;
    return buffer.sublist(start, _position);
  }

  /// Read Int16.
  int readInt16([bool bigEndian = false]) {
    final b = _next(2);

    final endian = bigEndian ? Endian.big : Endian.little;
    final x = b.buffer.asByteData().getUint16(0, endian);

    return x;
  }

  /// Read Int32.
  int readInt32([bool bigEndian = false]) {
    final b = _next(4);

    final endian = bigEndian ? Endian.big : Endian.little;
    final x = b.buffer.asByteData().getUint32(0, endian);

    return x;
  }

  /// Read Int64.
  int readInt64([bool bigEndian = false]) {
    final b = _next(8);

    final endian = bigEndian ? Endian.big : Endian.little;
    final x = b.buffer.asByteData().getUint64(0, endian);

    return x;
  }

  /// Read Int128.
  Int128 readInt128() {
    final b = _next(16);
    return Int128(b);
  }

  /// Read Int256.
  Int256 readInt256() {
    final b = _next(32);
    return Int256(b);
  }

  /// Read double.
  double readFloat64() {
    final b = _next(8);
    final x = b.buffer.asFloat64List(0, 1);

    return x.first;
  }

  /// Read boolean.
  bool readBool() {
    final b = readInt32();

    if (b == 0x997275B5) {
      return true;
    } else if (b == 0xBC799737) {
      return false;
    }

    throw Exception('Invalid boolean value.');
  }

  /// Read DateTime.
  DateTime readDateTime() {
    final seconds = readInt32();
    final tmp = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

    return tmp;
  }

  /// Read List&lt;TlObject&gt;.
  Vector<T> readVectorObject<T extends TlObject>() {
    final ctor = readInt32();
    assert(ctor == vectorCtor, 'Invalid type.');

    return readVectorObjectNoCtor<T>();
  }

  /// Read List&lt;TlObject&gt;.
  Vector<T> readVectorObjectNoCtor<T extends TlObject>() {
    final count = readInt32();
    final items = <T>[];

    for (int i = 0; i < count; i++) {
      items.add(readObject() as T);
    }

    return Vector(items);
  }

  /// Read List&lt;int32&gt;.
  Vector<int> readVectorInt32() {
    final ctor = readInt32();
    assert(ctor == vectorCtor, 'Invalid type.');

    final count = readInt32();
    final items = <int>[];

    for (int i = 0; i < count; i++) {
      items.add(readInt32());
    }

    return Vector(items);
  }

  /// Read List&lt;int64&gt;.
  Vector<int> readVectorInt64() {
    final ctor = readInt32();
    assert(ctor == vectorCtor, 'Invalid type.');

    final count = readInt32();
    final items = <int>[];

    for (int i = 0; i < count; i++) {
      items.add(readInt64());
    }

    return Vector(items);
  }

  /// Read List&lt;Uint8List&gt;.
  Vector<Uint8List> readVectorBytes() {
    final ctor = readInt32();
    assert(ctor == vectorCtor, 'Invalid type.');

    final count = readInt32();
    final items = <Uint8List>[];

    for (int i = 0; i < count; i++) {
      items.add(Uint8List.fromList(readBytes()));
    }

    return Vector(items);
  }

  /// Read List&lt;String&gt;.
  Vector<String> readVectorString() {
    final ctor = readInt32();
    assert(ctor == vectorCtor, 'Invalid type.');

    final count = readInt32();
    final items = <String>[];

    for (int i = 0; i < count; i++) {
      items.add(readString());
    }

    return Vector(items);
  }

  /// Read Uint8List.
  Uint8List readBytes() {
    var length = buffer[_position++];
    bool add3 = !(length < 254);

    if (length < 254) {
      // NOP
    } else {
      length = readInt16() + (buffer[_position++] << 16);
    }

    final tmp = _next(length);

    if (add3) {
      length += 3;
    }

    while (++length % 4 != 0) {
      _position++;
    }

    return Uint8List.fromList(tmp);
  }

  /// Read raw Uint8List.
  Uint8List readRawBytes(int length) {
    final b = _next(length);

    return b;
  }

  /// Read String.
  String readString() {
    const utf8Decoder = Utf8Decoder(allowMalformed: false);

    final codeUnits = readBytes();
    final tmp = utf8Decoder.convert(codeUnits);
    return tmp;
  }

  /// Read TlObject.
  TlObject readObject() {
    final obj = readTlObject(this);
    return obj;
  }
}
