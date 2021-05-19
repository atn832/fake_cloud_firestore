import 'package:cloud_firestore/cloud_firestore.dart';

import 'mock_document_snapshot.dart';

// ignore: subtype_of_sealed_class
class MockQueryDocumentSnapshot<T extends Object?>
    extends MockDocumentSnapshot<T> implements QueryDocumentSnapshot<T> {
  MockQueryDocumentSnapshot(DocumentReference<T> reference, String documentId,
      Map<String, dynamic>? rawDocument, T? convertedDocument, bool isConverted)
      : super(reference, documentId, rawDocument, convertedDocument,
            isConverted, true);

  @override
  bool get exists => true;

  @override
  T data() {
    return super.data()!;
  }
}
