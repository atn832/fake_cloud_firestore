import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import 'fake_aggregate_query.dart';
import 'query_snapshot_stream_manager.dart';

// ignore: subtype_of_sealed_class
/// This is a FakeQuery that remembers its parent. It is used to fire snapshots
/// whenever a document or collection changes.
abstract class FakeQueryWithParent<T extends Object?> implements Query<T> {
  /// The parent is not typed, because one query could be converted, while the
  /// parent is raw.
  FakeQueryWithParent? get parentQuery;

  @override
  FirebaseFirestore get firestore {
    // The only time parentQuery is null is when the FakeQueryWithParent is a
    // CollectionReference, in which case FakeCollectionReference overrides the
    // firestore getter. So no issue here.
    return parentQuery!.firestore;
  }

  @override
  Stream<QuerySnapshot<T>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource? source,
  }) {
    QuerySnapshotStreamManager().register<T>(this);
    final controller =
        QuerySnapshotStreamManager().getStreamController<T>(this);
    get().then((event) {
      if (controller.isClosed == false) {
        controller.add(event);
      }
    }, onError: (error) {
      if (controller.isClosed == false) {
        controller.addError(error);
      }
    });
    return controller.stream.distinct(_snapshotEquals);
  }

  @override
  AggregateQuery count() {
    return FakeAggregateQuery(this);
  }
}

final _unorderedDeepEquality = const DeepCollectionEquality.unordered();

bool _snapshotEquals(QuerySnapshot snapshot1, QuerySnapshot snapshot2) {
  if (snapshot1.docs.length != snapshot2.docs.length) {
    return false;
  }

  for (var i = 0; i < snapshot1.docs.length; i++) {
    if (snapshot1.docs[i].id != snapshot2.docs[i].id) {
      return false;
    }

    if (!_unorderedDeepEquality.equals(
        snapshot1.docs[i].data(), snapshot2.docs[i].data())) {
      return false;
    }
  }
  return true;
}
