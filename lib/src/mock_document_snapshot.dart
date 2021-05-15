import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/src/mock_snapshot_metadata.dart';
import 'package:cloud_firestore_mocks/src/util.dart';

import 'util.dart';

class MockDocumentSnapshot<T extends Object?> implements DocumentSnapshot<T> {
  final String _id;
  final Map<String, dynamic>? _document;
  final bool _exists;
  final DocumentReference<T> _reference;
  final MockSnapshotMetadata _metadata = MockSnapshotMetadata();

  MockDocumentSnapshot(this._reference, this._id, T? document, this._exists)
      : _document = deepCopy(document);

  @override
  String get id => _id;

  @override
  dynamic get(dynamic key) {
    if (_isCompositeKey(key)) {
      return getCompositeKeyValue(key);
    }
    return _document![key];
  }

  @override
  T? data() {
    if (_exists) {
      return deepCopy(_document);
    } else {
      return null;
    }
  }

  @override
  bool get exists => _exists;

  @override
  DocumentReference<T> get reference => _reference;

  @override
  SnapshotMetadata get metadata => _metadata;

  bool _isCompositeKey(String key) {
    return key.contains('.');
  }

  dynamic getCompositeKeyValue(String key) {
    final compositeKeyElements = key.split('.');
    dynamic value = _document!;
    for (final keyElement in compositeKeyElements) {
      value = value[keyElement];
      if (value == null) return null;
    }
    return value;
  }

  @override
  operator [](field) {
    // TODO: implement []
    throw UnimplementedError();
  }
}
