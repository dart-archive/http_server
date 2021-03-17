import 'package:http_server/src/has_next_iterator.dart';
import 'package:test/test.dart';

void main() {
  const mock_first_item = 'foo';
  const mock_last_item = 'bar';
  const mock_items = [mock_first_item, mock_last_item];
  group('When testing hasNext', () {
    test('should return true', () {
      final hasNextIterator = HasNextIterator(mock_items.iterator);
      hasNextIterator.moveNext();
      expect(hasNextIterator.hasNext, isTrue);
    });

    group('With a single item list', () {
      const mock_single_list = [mock_first_item];
      test('Should return true.', () {
        final hasNextIterator = HasNextIterator(mock_single_list.iterator);
        hasNextIterator.moveNext();
        expect(hasNextIterator.hasNext, isTrue);
      });
    });

    group('with an empty list', () {
      test('should return false.', () {
        final hasNextIterator = HasNextIterator([].iterator);
        hasNextIterator.moveNext();
        expect(hasNextIterator.hasNext, isFalse);
      });
    });

    group('when iterating beyond the end of the list', () {
      test('should return false', () {
        final hasNextIterator = HasNextIterator(mock_items.iterator);
        hasNextIterator.moveNext();
        hasNextIterator.moveNext();
        hasNextIterator.moveNext();
        expect(hasNextIterator.hasNext, isFalse);
      });
    });
  });

  group('When testing current', () {
    test('should return current item', () {
      final hasNextIterator = HasNextIterator(mock_items.iterator);
      hasNextIterator.moveNext();
      expect(
          hasNextIterator.current, allOf(isNotEmpty, equals(mock_first_item)));
    });

    test('should return last item item', () {
      final hasNextIterator = HasNextIterator(mock_items.iterator);
      hasNextIterator.moveNext();
      hasNextIterator.moveNext();
      expect(
          hasNextIterator.current, allOf(isNotEmpty, equals(mock_last_item)));
    });
  });

  group('When testing moveNext', () {
    test('should return true', () {
      final hasNextIterator = HasNextIterator(mock_items.iterator);
      expect(hasNextIterator.moveNext(), isTrue);
    });

    test('should return false', () {
      final hasNextIterator = HasNextIterator(mock_items.iterator);
      hasNextIterator.moveNext();
      hasNextIterator.moveNext();
      expect(hasNextIterator.moveNext(), isFalse);
    });
  });

  test('Throws if you call `hasNext` before `moveNext`', () {
    final hasNextIterator = HasNextIterator(mock_items.iterator);
    expect(() => hasNextIterator.hasNext, throwsA(isA<TypeError>()));
  });
}
