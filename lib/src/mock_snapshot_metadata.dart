import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';

class MockSnapshotMetadata extends Mock implements SnapshotMetadata {
  bool _hasPendingWrites;
  bool _isFromCache;

  MockSnapshotMetadata({
    hasPendingWrites = false,
    isFromCache = false,
  }) {
    _hasPendingWrites = hasPendingWrites;
    _isFromCache = isFromCache;
  }

  @override
  bool get hasPendingWrites => _hasPendingWrites;

  @override
  bool get isFromCache => _isFromCache;
}
