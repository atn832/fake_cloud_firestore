import 'package:cloud_firestore/cloud_firestore.dart';

// ignore: subtype_of_sealed_class
/// Wraps a DocumentSnapshot. The only difference with a DocumentSnapshot is
/// that it exists by definition.
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

  @override
  bool get exists {
    assert(snapshot.exists);
    return snapshot.exists;
  }

  @override
  get(Object field) => snapshot.get(field);

  @override
  String get id => snapshot.id;

  @override
  SnapshotMetadata get metadata => snapshot.metadata;

  @override
  DocumentReference<T> get reference => snapshot.reference;
}
