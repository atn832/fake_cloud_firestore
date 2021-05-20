import 'package:cloud_firestore/cloud_firestore.dart';

import 'converter.dart';
import 'mock_document_snapshot.dart';

// ignore: subtype_of_sealed_class
/// Takes a DocumentSnapshot, and wraps its data. The only difference with
/// MockDocumentSnapshot is that it exists by definition.
class MockQueryDocumentSnapshot<T extends Object?>
    extends MockDocumentSnapshot<T> implements QueryDocumentSnapshot<T> {
  MockQueryDocumentSnapshot.fromReference(
      DocumentSnapshot<T> snapshot, Converter<T>? converter)
      : super(
            snapshot.reference,
            snapshot.id,
            converter == null
                ? snapshot.data() as Map<String, dynamic>
                : converter.toFirestore(snapshot.data()!, null),
            snapshot.data(),
            converter != null,
            true);

  @override
  bool get exists => true;

  @override
  T data() {
    return super.data()!;
  }
}
