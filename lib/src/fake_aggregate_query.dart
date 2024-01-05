import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    hide AggregateQuery;
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as platform_interface;
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import 'fake_aggregate_query_snapshot.dart';

class FakeAggregateQuery implements AggregateQuery {
  final Query _query;
  final Iterable<AggregateField?> _aggregateFields;

  FakeAggregateQuery(this._query, this._aggregateFields);

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
  AggregateQuery count() {
    return _query.count();
  }

  AggregateQuerySnapshotPlatform _getAggregateQuerySnapshotPlatform({
    required QuerySnapshot<Object?> snapshot,
  }) {
    final dataMaps = snapshot.docs.map((e) => e.data() as Map<String, dynamic>);
    final delegate = AggregateQuerySnapshotPlatform(
      count: snapshot.size,
      sum: buildAggregateQueryResponseList(
        dataMaps: dataMaps,
        aggregateFields: _aggregateFields,
        aggregateType: AggregateType.sum,
      ),
      average: buildAggregateQueryResponseList(
        dataMaps: dataMaps,
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
    final nonNullFields = fields.whereNotNull();
    switch (type) {
      case AggregateType.sum:
        return nonNullFields.whereType<platform_interface.sum>();
      case AggregateType.average:
        return nonNullFields.whereType<platform_interface.average>();
      case AggregateType.count:
        return nonNullFields.whereType<platform_interface.count>();
      default:
        throw UnimplementedError('Unknown AggregateType: $type');
    }
  }

  @visibleForTesting
  static List<AggregateQueryResponse> buildAggregateQueryResponseList({
    required Iterable<Map<String, dynamic>> dataMaps,
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
    if (dataMaps.isEmpty || fields.isEmpty) return [];

    final valueMap = <String, double>{};
    for (final dataMap in dataMaps) {
      for (final field in fields) {
        if (field is platform_interface.sum) {
          final value = dataMap[field.field];
          if (value is num) {
            valueMap[field.field] = (valueMap[field.field] ?? 0) + value;
          }
        } else if (field is platform_interface.average) {
          final value = dataMap[field.field];
          if (value is num) {
            valueMap[field.field] =
                (valueMap[field.field] ?? 0) + (value / dataMaps.length);
          }
        } else {
          throw UnimplementedError(
              'Unsupported AggregateField: ${field.runtimeType}');
        }
      }
    }
    return convertValuesMapToResponseList(valueMap, aggregateType);
  }
}
