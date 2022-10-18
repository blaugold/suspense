import 'dart:async';

enum FutureStatus {
  pending,
  resolved,
  rejected,
}

final _futureStatus = Expando<FutureStatus>('FutureStatus');
final _futureValue = Expando<Object>('FutureValue');
final _futureStackTrace = Expando<Object>('FutureStackTrace');

Future<T> futureWithValue<T>(T value) {
  final future = Future<T>.value(value);
  _futureStatus[future] = FutureStatus.resolved;
  _futureValue[future] = value;
  return future;
}

Future<T> futureWithError<T>(Object error, [StackTrace? stackTrace]) {
  final future = Future<T>.error(error, stackTrace);
  _futureStatus[future] = FutureStatus.rejected;
  _futureValue[future] = error;
  _futureStackTrace[future] = stackTrace;
  return future;
}

void initFuture<T>(Future<T> future) {
  if (future.isSuspenseFuture) {
    return;
  }

  _futureStatus[future] = FutureStatus.pending;
  future.then(
    (value) {
      _futureStatus[future] = FutureStatus.resolved;
      _futureValue[future] = value;
    },
    onError: (error, stackTrace) {
      _futureStatus[future] = FutureStatus.rejected;
      _futureValue[future] = error;
      _futureStackTrace[future] = stackTrace;
    },
  );
}

extension SuspenseFuture<T> on Future<T> {
  bool get isSuspenseFuture => _futureStatus[this] != null;
  FutureStatus get status => _futureStatus[this]!;
  T get value => _futureValue[this] as T;
  Object get error => _futureValue[this] as Object;
  StackTrace? get stackTrace => _futureStackTrace[this] as StackTrace?;
}

typedef AwaitFutureInterceptor = Future<T> Function<T>(Future<T> future);

AwaitFutureInterceptor? awaitFutureInterceptor;

T await<T>(FutureOr<T> future) {
  if (future is! Future<T>) {
    return future;
  }

  future = awaitFutureInterceptor!(future);

  switch (future.status) {
    case FutureStatus.pending:
      throw SuspendException();
    case FutureStatus.resolved:
      return future.value;
    case FutureStatus.rejected:
      final error = future.error;
      final stackTrace = future.stackTrace;
      if (stackTrace != null) {
        Error.throwWithStackTrace(error, stackTrace);
      } else {
        throw error;
      }
  }
}

class SuspendException implements Exception {}
