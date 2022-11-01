import 'package:cloud_firestore/cloud_firestore.dart';

class FakeAggregateQuerySnapshot implements AggregateQuerySnapshot {
  final Query _query;
  final int _count;

  FakeAggregateQuerySnapshot(this._query, this._count);

  @override
  int get count => _count;

  @override
  Query<Object?> get query => _query;
}
