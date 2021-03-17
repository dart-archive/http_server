// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// [Iterator] which wraps another [Iterator] and saves the most recent result
/// from [moveNext].
class HasNextIterator<E> implements Iterator<E> {
  final Iterator<E> _iterator;

  /// The result of the last call to [moveNext].
  bool? _hasNext;

  /// The result of the last call to [moveNext].
  ///
  /// You must call [moveNext] at least once before calling this getter.
  bool get hasNext => _hasNext!;

  HasNextIterator(this._iterator);

  /// Must be called before reading [current] or [hasNext].
  @override
  bool moveNext() => _hasNext = _iterator.moveNext();

  @override
  E get current => _iterator.current;
}
