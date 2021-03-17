import 'package:http_server/src/has_current_iterator.dart';
import 'package:test/test.dart';

void main() {
  const mock_first_item = 'foo';
  const mock_last_item = 'bar';
  const mock_items = [mock_first_item, mock_last_item];
  group('When testing hasCurrent', () {
    test('should return false to start', () {
      final hasCurrentIterator = HasCurrentIterator(mock_items.iterator);
      expect(hasCurrentIterator.hasCurrent, isFalse);
    });

    group('With a single item list', () {
      const mock_single_list = [mock_first_item];
      test('Should return true.', () {
        final hasCurrentIterator =
            HasCurrentIterator(mock_single_list.iterator);
        hasCurrentIterator.moveNext();
        expect(hasCurrentIterator.hasCurrent, isTrue);
      });
    });

    group('with an empty list', () {
      test('should return false.', () {
        final hasCurrentIterator = HasCurrentIterator([].iterator);
        hasCurrentIterator.moveNext();
        expect(hasCurrentIterator.hasCurrent, isFalse);
      });
    });

    group('when iterating beyond the end of the list', () {
      test('should return false', () {
        final hasCurrentIterator = HasCurrentIterator(mock_items.iterator);
        hasCurrentIterator.moveNext();
        hasCurrentIterator.moveNext();
        hasCurrentIterator.moveNext();
        expect(hasCurrentIterator.hasCurrent, isFalse);
      });
    });
  });

  group('When testing current', () {
    test('should return current item', () {
      final hasCurrentIterator = HasCurrentIterator(mock_items.iterator);
      hasCurrentIterator.moveNext();
      expect(hasCurrentIterator.current,
          allOf(isNotEmpty, equals(mock_first_item)));
    });

    test('should return last item item', () {
      final hasCurrentIterator = HasCurrentIterator(mock_items.iterator);
      hasCurrentIterator.moveNext();
      hasCurrentIterator.moveNext();
      expect(hasCurrentIterator.current,
          allOf(isNotEmpty, equals(mock_last_item)));
    });
  });

  group('When testing moveNext', () {
    test('should return true', () {
      final hasCurrentIterator = HasCurrentIterator(mock_items.iterator);
      expect(hasCurrentIterator.moveNext(), isTrue);
    });

    test('should return false', () {
      final hasCurrentIterator = HasCurrentIterator(mock_items.iterator);
      hasCurrentIterator.moveNext();
      hasCurrentIterator.moveNext();
      expect(hasCurrentIterator.moveNext(), isFalse);
    });
  });
}
