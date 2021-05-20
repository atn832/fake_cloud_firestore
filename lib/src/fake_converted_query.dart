// ignore: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';

import 'converter.dart';
import 'fake_query_interface.dart';
import 'mock_query.dart';
import 'mock_query_snapshot.dart';

// ignore: subtype_of_sealed_class
/// A converted query. It should always be the last query in the chain, so we
/// don't need to implement where, startAt, ..., withConverter.
class FakeConvertedQuery<T extends Object?> implements QueryWithParent<T> {
  final QueryWithParent _nonConvertedParentQuery;
  final Converter<T> _converter;

  FakeConvertedQuery(this._nonConvertedParentQuery, this._converter)
      : assert(_nonConvertedParentQuery is Query<Map<String, dynamic>>,
            'FakeConvertedQuery expects a non-converted query.');

  @override
  Future<QuerySnapshot<T>> get([GetOptions? options]) async {
    final rawDocSnapshots = (await _nonConvertedParentQuery.get()).docs;
    final convertedSnapshots = rawDocSnapshots
        .map((rawDocSnapshot) => rawDocSnapshot.reference
            .withConverter<T>(
                fromFirestore: _converter.fromFirestore,
                toFirestore: _converter.toFirestore)
            .get())
        .toList();
    return MockQuerySnapshot(await Future.wait(convertedSnapshots));
  }

  @override
  Stream<QuerySnapshot<T>> snapshots({bool includeMetadataChanges = false}) {
    QuerySnapshotStreamManager().register<T>(this);
    final controller =
        QuerySnapshotStreamManager().getStreamController<T>(this);
    controller.addStream(Stream.fromFuture(get()));
    return controller.stream.distinct(snapshotEquals);
  }

  @override
  QueryWithParent? get parentQuery => _nonConvertedParentQuery;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
