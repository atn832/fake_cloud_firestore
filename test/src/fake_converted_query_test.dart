import 'package:fake_cloud_firestore/src/converter.dart';
import 'package:fake_cloud_firestore/src/fake_converted_query.dart';
import 'package:fake_cloud_firestore/src/fake_query_with_parent.dart';
import 'package:fake_cloud_firestore/src/mock_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ignore: subtype_of_sealed_class
class MockFakeQueryWithParent<T> extends Mock implements MockQuery<T> {}

class MockConverter<T> extends Mock implements Converter<T> {}

void main() {
  test('FakeQueryWithParentImpl.limit should throw NoSuchMethodError', () {
    expect(
      () => FakeQueryWithParentImpl().limit(1),
      throwsA(isA<NoSuchMethodError>()),
    );
  });

  test('FakeConvertedQuery.limit should return normally', () {
    // arrange
    final mockFakeQueryWithParent =
        MockFakeQueryWithParent<Map<String, dynamic>>();
    final mockConverter = MockConverter<Map<String, dynamic>>();

    // act
    final query = FakeConvertedQuery<Map<String, dynamic>>(
      mockFakeQueryWithParent,
      mockConverter,
    );

    // assert
    expect(() => query.limit(1), returnsNormally);
  });
}

// ignore: subtype_of_sealed_class
class FakeQueryWithParentImpl extends FakeQueryWithParent {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
