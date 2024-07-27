import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/src/mock_document_snapshot.dart';

// ignore: subtype_of_sealed_class
/// Wraps a DocumentSnapshot. The only difference with a DocumentSnapshot is
/// that it exists by definition.
/// TODO: check if MockQueryDocumentSnapshot could extend MockDocumentSnapshot.
class MockQueryDocumentSnapshot<T extends Object?>
    implements QueryDocumentSnapshot<T> {
  final DocumentSnapshot<T> snapshot;
  MockQueryDocumentSnapshot(this.snapshot);

  @override
  dynamic operator [](Object field) => snapshot[field];

  @override
  T data() {
    return snapshot.data()!;
  }

  Map<String, dynamic>? rawData() {
    if (snapshot is MockQueryDocumentSnapshot) {
      return (snapshot as MockQueryDocumentSnapshot).rawData();
    }
    return (snapshot as MockDocumentSnapshot).rawData();
  }

  @override
  bool get exists {
    assert(snapshot.exists);
    return snapshot.exists;
  }

  @override
  dynamic get(Object field) => snapshot.get(field);

  @override
  String get id => snapshot.id;

  @override
  SnapshotMetadata get metadata => snapshot.metadata;

  @override
  DocumentReference<T> get reference => snapshot.reference;
}
