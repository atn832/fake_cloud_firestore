import 'package:cloud_firestore/cloud_firestore.dart';

import 'fake_aggregate_query_snapshot.dart';

class FakeAggregateQuery implements AggregateQuery {
  final Query _query;

  FakeAggregateQuery(this._query);

  @override
  Future<AggregateQuerySnapshot> get(
      {AggregateSource source = AggregateSource.server}) async {
    final snapshot = await _query.get();
    return FakeAggregateQuerySnapshot(_query, snapshot.size);
  }

  @override
  Query<Object?> get query => _query;
}
