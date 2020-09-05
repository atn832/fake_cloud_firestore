import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/src/mock_document_reference.dart';

import 'mock_document_snapshot.dart';

class MockQueryDocumentSnapshot extends MockDocumentSnapshot
    implements QueryDocumentSnapshot {
  MockQueryDocumentSnapshot(MockDocumentReference reference, String documentId,
      Map<String, dynamic> document)
      : super(reference, documentId, document, true);
}
