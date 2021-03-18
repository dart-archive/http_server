// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// [Iterator] which wraps another [Iterator] and allows you to ask if there
/// is a valid value in [current].
class HasCurrentIterator<E> implements Iterator<E> {
  final Iterator<E> _iterator;

  /// The result of the last call to [moveNext].
  bool _hasCurrent = false;

  /// Whether or not `current` has a valid value.
  ///
  /// This starts out as `false`, and then stores the value of the previous
  /// `moveNext` call.
  bool get hasCurrent => _hasCurrent;

  HasCurrentIterator(this._iterator);

  /// Must be called before reading [current] or [hasCurrent].
  @override
  bool moveNext() => _hasCurrent = _iterator.moveNext();

  @override
  E get current => _iterator.current;
}
