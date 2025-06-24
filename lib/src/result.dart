
import 'package:t/src/core.dart';
import 'package:t/src/g/mtproto.dart';

/// RPC Result.
class Result<T extends TlObject> {
  const Result._(this.result, this.error);

  /// Creates a successful result.
  const Result.ok(T this.result) : error = null;

  /// Creates an error result.
  const Result.error(RpcError this.error) : result = null;

  /// Actual result.
  final T? result;

  /// Error.
  final RpcError? error;

  Result<S> to<S extends TlObject>() {
    if (result == null) {
      return Result<S>._(null, error);
    } else {
      return Result<S>._(result as S, null);
    }
  }

  Result<Vector<S>> toVector<S>() {
    final r = result;

    if (r == null) {
      return Result<Vector<S>>._(null, error);
    } else if (r is Vector) {
      final s = r.items.map((e) => e as S);
      final v = Vector(s.toList());
      return Result<Vector<S>>._(v, null);
    }

    throw Exception('Not a vector.');
  }

  @override
  String toString() {
    if (result != null) {
      return result.toString();
    }

    if (error != null) {
      return error.toString();
    }

    return '';
  }
}
