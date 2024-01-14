import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    hide AggregateQuery;
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as platform_interface;
import 'package:collection/collection.dart';
import 'package:fake_cloud_firestore/src/aggregate_type_extension.dart';
import 'package:flutter/foundation.dart';

import 'fake_aggregate_query_snapshot.dart';

class FakeAggregateQuery implements AggregateQuery {
  final Query _query;
  final Iterable<AggregateField?> _aggregateFields;

  FakeAggregateQuery(this._query, [this._aggregateFields = const []]);

  @override
  Future<AggregateQuerySnapshot> get(
      {AggregateSource source = AggregateSource.server}) async {
    final snapshot = await _query.get();
    final delegate = _getAggregateQuerySnapshotPlatform(snapshot: snapshot);
    return FakeAggregateQuerySnapshot(_query, delegate);
  }

  @override
  Query<Object?> get query => _query;

  @override
  AggregateQuery count() => _query.count();

  AggregateQuerySnapshotPlatform _getAggregateQuerySnapshotPlatform({
    required QuerySnapshot<Object?> snapshot,
  }) {
    final delegate = AggregateQuerySnapshotPlatform(
      count: snapshot.size,
      sum: buildAggregateQueryResponseList(
        documentSnapshots: snapshot.docs,
        aggregateFields: _aggregateFields,
        aggregateType: AggregateType.sum,
      ),
      average: buildAggregateQueryResponseList(
        documentSnapshots: snapshot.docs,
        aggregateFields: _aggregateFields,
        aggregateType: AggregateType.average,
      ),
    );
    return delegate;
  }

  @visibleForTesting
  static List<AggregateQueryResponse> convertValuesMapToResponseList(
    Map<String, double> keyNumMap,
    AggregateType aggregateType,
  ) {
    return keyNumMap.entries
        .map((e) => AggregateQueryResponse(
              type: aggregateType,
              value: e.value,
              field: e.key,
            ))
        .toList();
  }

  @visibleForTesting
  static Iterable<AggregateField> getFieldsWithType({
    required Iterable<AggregateField?> fields,
    required AggregateType type,
  }) {
    return fields
        .whereNotNull()
        .where((e) => e.runtimeType == type.aggregateFieldType);
  }

  @visibleForTesting
  static String getAggregateFieldName(AggregateField aggregateField) {
    switch (aggregateField) {
      case platform_interface.sum(field: var field) ||
            platform_interface.average(field: var field):
        return field;
      default:
        throw UnimplementedError(
            'Unsupported AggregateField: ${aggregateField.runtimeType}');
    }
  }

  @visibleForTesting
  static List<AggregateQueryResponse> buildAggregateQueryResponseList({
    required Iterable<DocumentSnapshot> documentSnapshots,
    required Iterable<AggregateField?> aggregateFields,
    required AggregateType aggregateType,
  }) {
    assert(
      aggregateType == AggregateType.sum ||
          aggregateType == AggregateType.average,
      'This method only supports AggregateType.sum and AggregateType.average',
    );

    // only support sum and average
    if (![AggregateType.sum, AggregateType.average].contains(aggregateType)) {
      return [];
    }

    final fields = getFieldsWithType(
      fields: aggregateFields,
      type: aggregateType,
    );
    if (documentSnapshots.isEmpty || fields.isEmpty) return [];

    final aggregateValues = <String, double>{};

    for (final aggregateField in fields) {
      final fieldName = getAggregateFieldName(aggregateField);
      for (final documentSnapshot in documentSnapshots) {
        final value = documentSnapshot.get(fieldName);
        if (value is! num) {
          throw UnsupportedError('value must be a num: ${value.runtimeType}');
        }
        if (aggregateField is platform_interface.sum) {
          aggregateValues[aggregateField.field] =
              (aggregateValues[aggregateField.field] ?? 0) + value;
        } else if (aggregateField is platform_interface.average) {
          aggregateValues[aggregateField.field] =
              (aggregateValues[aggregateField.field] ?? 0) +
                  (value / documentSnapshots.length);
        } else {
          throw UnimplementedError(
              'Unsupported AggregateField: ${aggregateField.runtimeType}');
        }
      }
    }
    return convertValuesMapToResponseList(aggregateValues, aggregateType);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
