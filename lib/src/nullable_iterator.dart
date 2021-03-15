///
/// Re-implementation of [Iterator] which allows for a Nullable
/// [current] element.
///
class NullableIterator<E> {
  final List<E> _items;
  final int _length;
  int _index = 0;
  E? _current;

  NullableIterator(this._items) : _length = _items.length;

  /// Advances the iterator to the next element of the iteration.
  ///
  /// Should be called before reading [current].
  /// If the call to `moveNext` returns `true`,
  /// then [current] will contain the next element of the iteration
  /// until `moveNext` is called again.
  /// If the call returns `false`, there are no further elements
  /// and [current] should not be used any more, since it will return `null`.
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
    if (_index >= _length) {
      _current = null;
      return false;
    }
    _current = _items[_index];
    _index++;
    return true;
  }

  /// The current element.
  ///
  /// If the iterator has not yet been moved to the first element
  /// ([moveNext] has not been called yet),
  /// or if the iterator has been moved past the last element of the [Iterable]
  /// ([moveNext] has returned false),
  /// then [current] returns `null`.
  /// An [Iterator] may either throw or return an iterator specific default value
  /// in that case.
  ///
  /// The `current` getter should keep its value until the next call to
  /// [moveNext], even if an underlying collection changes.
  /// After a successful call to `moveNext`, the user doesn't need to cache
  /// the current value, but can keep reading it from the iterator, assuming
  /// a valid value is returned. Otherwise, `null` is returned since there are
  /// no more items to iterate.
  E? get current => _current;
}

extension NullableIteratorExtension<E> on List<E> {
  /// Returns a new [NullableIterator] for this instance.
  NullableIterator<E> get nullableIterator => NullableIterator<E>(this);
}
