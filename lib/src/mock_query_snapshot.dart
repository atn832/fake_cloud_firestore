import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/src/mock_snapshot_metadata.dart';

import 'mock_query_document_snapshot.dart';

class MockQuerySnapshot<T extends Object?> implements QuerySnapshot<T> {
  final List<DocumentSnapshot<T>> _docSnapshots;

  final List<DocumentChange<T>> _documentChanges = <DocumentChange<T>>[];

  @override
  final SnapshotMetadata metadata;

  MockQuerySnapshot(
    this._docSnapshots,
    bool isFromCache, {
    final List<DocumentChange<T>>? documentChanges,
  }) : metadata = MockSnapshotMetadata(isFromCache: isFromCache) {
    if (documentChanges != null) {
      _documentChanges.addAll(documentChanges);
    }
  }

  @override
  List<QueryDocumentSnapshot<T>> get docs => _docSnapshots.map((doc) => MockQueryDocumentSnapshot(doc)).toList();

  @override
  List<DocumentChange<T>> get docChanges => _documentChanges;

  @override
  int get size => _docSnapshots.length;
}
