import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/src/mock_document_change.dart';
import 'package:fake_cloud_firestore/src/mock_snapshot_metadata.dart';

import 'mock_query_document_snapshot.dart';

class MockQuerySnapshot<T extends Object?> implements QuerySnapshot<T> {
  final List<DocumentSnapshot<T>> _docSnapshots;

  final List<DocumentChange<T>> _documentChanges = <DocumentChange<T>>[];

  @override
  final SnapshotMetadata metadata;

  MockQuerySnapshot(
    this._docSnapshots,
    bool isFromCache,
  ) : metadata = MockSnapshotMetadata(isFromCache: isFromCache) {
    // TODO: support another change type (removed, modified).
    // ref: https://pub.dev/documentation/cloud_firestore_platform_interface/latest/cloud_firestore_platform_interface/DocumentChangeType-class.html
    _docSnapshots.asMap().forEach((index, docSnapshot) {
      _documentChanges.add(MockDocumentChange<T>(
        docSnapshot,
        DocumentChangeType.added,
        oldIndex:
            -1, // See: https://pub.dev/documentation/cloud_firestore/latest/cloud_firestore/DocumentChange/oldIndex.html
        newIndex: index,
      ));
    });
  }

  @override
  List<QueryDocumentSnapshot<T>> get docs =>
      _docSnapshots.map((doc) => MockQueryDocumentSnapshot(doc)).toList();

  @override
  List<DocumentChange<T>> get docChanges => _documentChanges;

  @override
  int get size => _docSnapshots.length;
}
