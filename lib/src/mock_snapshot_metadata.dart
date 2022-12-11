import 'package:cloud_firestore/cloud_firestore.dart';

class MockSnapshotMetadata implements SnapshotMetadata {
  @override
  final bool isFromCache;

  MockSnapshotMetadata({
    required this.isFromCache,
  });

  @override
  bool get hasPendingWrites => false;
}
