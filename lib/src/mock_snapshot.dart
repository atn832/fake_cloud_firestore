import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/src/mock_document_change.dart';
import 'package:mockito/mockito.dart';

class MockSnapshot extends Mock implements QuerySnapshot {
  final List<DocumentSnapshot> _documents;

  final List<DocumentChange> _documentChanges = <DocumentChange>[];

  MockSnapshot(this._documents) {
    // TODO: support another change tyep (removed, modified).
    // ref: https://pub.dev/documentation/cloud_firestore_platform_interface/latest/cloud_firestore_platform_interface/DocumentChangeType-class.html
    _documents.asMap().forEach((index, document) {
      _documentChanges.add(MockDocumentChange(
        document,
        DocumentChangeType.added,
        oldIndex: -1, // See: https://pub.dev/documentation/cloud_firestore/latest/cloud_firestore/DocumentChange/oldIndex.html
        newIndex: index,
      ));
    });
  }

  @override
  List<DocumentSnapshot> get documents => _documents;

  @override
  List<DocumentChange> get documentChanges => _documentChanges;
}
