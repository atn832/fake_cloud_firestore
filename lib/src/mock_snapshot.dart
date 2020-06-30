import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/src/mock_document_change.dart';
import 'package:mockito/mockito.dart';

class MockSnapshot extends Mock implements QuerySnapshot {
  final List<DocumentSnapshot> _documents;

  final List<DocumentChange> _documentChanges = <DocumentChange>[];

  MockSnapshot(this._documents) {
    _documents.forEach((document) {
      _documentChanges.add(MockDocumentChange(document));
    });
  }

  @override
  List<DocumentSnapshot> get documents => _documents;

  List<DocumentChange> get documentChanges => _documentChanges;
}
