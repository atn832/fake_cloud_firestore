import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';

class MockSnapshotMetadata extends Mock implements SnapshotMetadata {
  @override
  bool get hasPendingWrites => false;

  @override
  bool get isFromCache => false;
}
