import 'package:cloud_firestore/cloud_firestore.dart';

import 'mock_document_snapshot.dart';

class MockQueryDocumentSnapshot extends MockDocumentSnapshot
    implements QueryDocumentSnapshot {
  MockQueryDocumentSnapshot(DocumentReference reference, String documentId,
      Map<String, dynamic>? document)
      : super(reference, documentId, document, true);

  @override
  bool get exists => true;

  @override
  Map<String, dynamic> data() {
    return super.data()!;
  }
}
