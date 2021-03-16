import 'package:http_server/src/has_next_iterator.dart';
import 'package:test/test.dart';

void main() {
  const mock_first_item = 'foo';
  const mock_last_item = 'bar';
  const mock_items = [mock_first_item, mock_last_item];
  group('When testing hasNext', () {
    test('should return true', () {
      final hasNextIterator = HasNextIterator(mock_items);
      hasNextIterator.moveNext();

      final actual = hasNextIterator.hasNext;

      expect(actual, isTrue);
    });

    group('With a single item list', () {
      const mock_single_list = [mock_first_item];
      test('Should return true.', () {
        final hasNextIterator = HasNextIterator(mock_single_list);

        final actual = hasNextIterator.hasNext;

        expect(actual, isTrue);
      });
    });

    group('with an empty list', () {
      test('should return false.', () {
        final hasNextIterator = HasNextIterator([]);

        final actual = hasNextIterator.hasNext;

        expect(actual, isFalse);
      });
    });

    group('when iterating beyond the end of the list', () {
      test('should return false', () {
        final hasNextIterator = HasNextIterator(mock_items);
        hasNextIterator.moveNext();
        hasNextIterator.moveNext();
        hasNextIterator.moveNext();

        final actual = hasNextIterator.hasNext;

        expect(actual, isFalse);
      });
    });
  });

  group('When testing current', () {
    test('should return current item', () {
      final hasNextIterator = HasNextIterator(mock_items);
      hasNextIterator.moveNext();

      final actual = hasNextIterator.current;

      expect(actual, allOf(isNotEmpty, equals(mock_first_item)));
    });

    test('should return last item item', () {
      final hasNextIterator = HasNextIterator(mock_items);
      hasNextIterator.moveNext();
      hasNextIterator.moveNext();

      final actual = hasNextIterator.current;

      expect(actual, allOf(isNotEmpty, equals(mock_last_item)));
    });
  });

  group('When testing moveNext', () {
    test('should return true', () {
      final hasNextIterator = HasNextIterator(mock_items);

      final actual = hasNextIterator.moveNext();

      expect(actual, isTrue);
    });

    test('should return false', () {
      final hasNextIterator = HasNextIterator(mock_items);
      hasNextIterator.moveNext();
      hasNextIterator.moveNext();

      final actual = hasNextIterator.moveNext();

      expect(actual, isFalse);
    });
  });
}
