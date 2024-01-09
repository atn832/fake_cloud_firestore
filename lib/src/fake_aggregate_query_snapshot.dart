import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';

class FakeAggregateQuerySnapshot implements AggregateQuerySnapshot {
  final Query _query;
  final AggregateQuerySnapshotPlatform _delegate;

  FakeAggregateQuerySnapshot(this._query, this._delegate);

  @override
  int? get count => _delegate.count;

  @override
  Query<Object?> get query => _query;

  @override
  double? getAverage(String field) => _delegate.getAverage(field);

  @override
  double? getSum(String field) => _delegate.getSum(field);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
