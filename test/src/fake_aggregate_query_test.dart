import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fake_cloud_firestore/src/fake_aggregate_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeAggregateQuery', () {
    late FakeFirebaseFirestore firestore;

    setUpAll(() {
      firestore = FakeFirebaseFirestore();
    });

    tearDownAll(() {
      firestore.clearPersistence();
    });

    setUp(() {
      final collection = firestore.collection('my_shops');
      collection.add({'shopId': '001', 'apple': 18, 'banana': 23});
      collection.add({'shopId': '002', 'apple': 12, 'banana': 34});
    });

    tearDown(() {
      firestore.clearPersistence();
    });

    group('convertValuesMapToResponseList', () {
      test('should returns list of AggregateQueryResponse from map', () {
        final keyNumMap = <String, double>{
          'apple': 18,
          'banana': 23,
        };
        final result = FakeAggregateQuery.convertValuesMapToResponseList(
          keyNumMap,
          AggregateType.sum,
        );
        expect(result.map((e) => e.encode()), [
          AggregateQueryResponse(
            type: AggregateType.sum,
            value: 18,
            field: 'apple',
          ).encode(),
          AggregateQueryResponse(
            type: AggregateType.sum,
            value: 23,
            field: 'banana',
          ).encode(),
        ]);
      });
    });

    group('getAggregateFieldName', () {
      test('should returns field name for AggregateField sum', () {
        final field = sum('apple');
        final fieldName = FakeAggregateQuery.getAggregateFieldName(field);
        expect(fieldName, 'apple');
      });

      test('should returns field name for AggregateField average', () {
        final field = average('cherry');
        final fieldName = FakeAggregateQuery.getAggregateFieldName(field);
        expect(fieldName, 'cherry');
      });

      test('should throw for unsupported AggregateField like count', () {
        final field = count();
        expect(
          () => FakeAggregateQuery.getAggregateFieldName(field),
          throwsUnimplementedError,
        );
      });
    });

    group('buildAggregateQueryResponseList', () {
      test(
          'should returns list of AggregateQueryResponse with sum type from maps and fields',
          () async {
        final querySnapshot = await firestore.collection('my_shops').get();
        final aggregateFields = [
          sum('apple'),
          sum('banana'),
        ];
        final result = FakeAggregateQuery.buildAggregateQueryResponseList(
          documentSnapshots: querySnapshot.docs,
          aggregateFields: aggregateFields,
          aggregateType: AggregateType.sum,
        );
        expect(result.map((e) => e.encode()), [
          AggregateQueryResponse(
            type: AggregateType.sum,
            value: 30,
            field: 'apple',
          ).encode(),
          AggregateQueryResponse(
            type: AggregateType.sum,
            value: 57,
            field: 'banana',
          ).encode(),
        ]);
      });

      test(
          'should returns list of AggregateQueryResponse with average type from maps and fields',
          () async {
        final querySnapshot = await firestore.collection('my_shops').get();
        final aggregateFields = [
          average('apple'),
          average('banana'),
        ];
        final result = FakeAggregateQuery.buildAggregateQueryResponseList(
          documentSnapshots: querySnapshot.docs,
          aggregateFields: aggregateFields,
          aggregateType: AggregateType.average,
        );
        expect(result.map((e) => e.encode()), [
          AggregateQueryResponse(
            type: AggregateType.average,
            value: 15,
            field: 'apple',
          ).encode(),
          AggregateQueryResponse(
            type: AggregateType.average,
            value: 28.5,
            field: 'banana',
          ).encode(),
        ]);
      });
    });

    group('getFieldsWithType', () {
      test('should return sum fields when type is AggregateType.sum', () {
        final fields = [
          sum('apple'),
          sum('strawberry'),
          average('banana'),
          count(),
        ];
        final result = FakeAggregateQuery.getFieldsWithType(
          fields: fields,
          type: AggregateType.sum,
        );
        expect(result.whereType<sum>().length, 2);
        expect(result.every((e) => e is sum), isTrue);
      });

      test('should return average fields when type is AggregateType.average',
          () {
        final fields = [
          sum('apple'),
          average('banana'),
          average('orange'),
          count(),
        ];
        final result = FakeAggregateQuery.getFieldsWithType(
          fields: fields,
          type: AggregateType.average,
        );
        expect(result.whereType<average>().length, 2);
        expect(result.every((e) => e is average), isTrue);
      });
    });
  });
}
