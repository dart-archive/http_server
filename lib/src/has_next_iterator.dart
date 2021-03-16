// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

///
/// Re-implementation of [Iterator] which saves the most recent result from
/// [moveNext].
///
class HasNextIterator<E> {
  final List<E> _items;
  final int _length;
  bool _hasNext = true;
  int _index = 0;
  E? _current;

  HasNextIterator(this._items)
      : _length = _items.length,
        // Empty lists should never have any next elements
        _hasNext = _items.isEmpty ? false : true;

  /// Advances the iterator to the next element of the iteration.
  ///
  /// Should be called before reading [current].
  /// If the call to `moveNext` returns `true`,
  /// then [current] will contain the next element of the iteration
  /// until `moveNext` is called again.
  /// If the call returns `false`, there are no further elements
  /// and [current] should not be used any more.
  ///
  /// It is safe to call [moveNext] after it has already returned `false`,
  /// but it must keep returning `false` and not have any other effect.
  ///
  /// A call to `moveNext` may throw for various reasons,
  /// including a concurrent change to an underlying collection.
  /// If that happens, the iterator may be in an inconsistent
  /// state, and any further behavior of the iterator is unspecified,
  /// including the effect of reading [current].
  bool moveNext() {
    if (_hasNext) {
      // We have more items to iterate, check if we have another item or
      // we're at the end of the list.
      if (_index >= _length) {
        _current = null;
        // At the end of our list, we have no more items.
        _hasNext = false;
      } else {
        _current = _items[_index];
        _index++;
        // We still have another item to move to
        _hasNext = true;
      }
    }
    return _hasNext;
  }

  /// Whether this instance has more items to iterate.
  ///
  /// In essence, it stores the most recent result from [moveNext].
  bool get hasNext => _hasNext;

  /// The current element.
  ///
  /// If the iterator has not yet been moved to the first element
  /// ([moveNext] has not been called yet),
  /// or if the iterator has been moved past the last element of the [Iterable]
  /// ([moveNext] has returned false),
  /// then [current] is unspecified.
  /// An [Iterator] may either throw or return an iterator specific default value
  /// in that case.
  ///
  /// The `current` getter should keep its value until the next call to
  /// [moveNext], even if an underlying collection changes.
  /// After a successful call to `moveNext`, the user doesn't need to cache
  /// the current value, but can keep reading it from the iterator.
  E get current => _current as E;
}

extension HasNextIteratorExtension<E> on List<E> {
  /// Returns a new [HasNextIterator] for this instance.
  HasNextIterator<E> get hasNextIterator => HasNextIterator<E>(this);
}
