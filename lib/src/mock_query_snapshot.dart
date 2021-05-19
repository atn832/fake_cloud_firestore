import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/src/mock_document_change.dart';

import 'converter.dart';
import 'mock_query_document_snapshot.dart';

class MockQuerySnapshot<T extends Object?> implements QuerySnapshot<T> {
  final List<DocumentSnapshot<T>> _documents;
  final Converter<T>? _converter;

  final List<DocumentChange<T>> _documentChanges = <DocumentChange<T>>[];

  MockQuerySnapshot(this._documents, this._converter) {
    // TODO: support another change type (removed, modified).
    // ref: https://pub.dev/documentation/cloud_firestore_platform_interface/latest/cloud_firestore_platform_interface/DocumentChangeType-class.html
    _documents.asMap().forEach((index, document) {
      _documentChanges.add(MockDocumentChange<T>(
        document,
        DocumentChangeType.added,
        oldIndex:
            -1, // See: https://pub.dev/documentation/cloud_firestore/latest/cloud_firestore/DocumentChange/oldIndex.html
        newIndex: index,
      ));
    });
  }

  @override
  List<QueryDocumentSnapshot<T>> get docs => _documents.map((doc) {
        if (_converter == null) {
          assert(doc.data() is Map<String, dynamic>);
          // We return a regular, non-converted Snapshot<Map<String, dynamic>>.
          return MockQueryDocumentSnapshot(doc.reference, doc.id,
              doc.data() as Map<String, dynamic>, _converter);
        }
        // With converter. We return a Snapshot<T>. Since we made
        // MockDocumentSnapshot require a Map<String, dynamic>, we have to use
        // toFirestore to convert T back into a Map.
        return MockQueryDocumentSnapshot(doc.reference, doc.id,
            _converter!.toFirestore(doc.data()!, null), _converter);
      }).toList();

  @override
  List<DocumentChange<T>> get docChanges => _documentChanges;

  @override
  // TODO: implement metadata
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  int get size => _documents.length;
}
