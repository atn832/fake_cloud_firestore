import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fake_cloud_firestore/src/converter.dart';
import 'package:fake_cloud_firestore/src/mock_document_reference.dart';
import 'package:fake_cloud_firestore/src/mock_snapshot_metadata.dart';
import 'package:fake_cloud_firestore/src/util.dart';

// Intentional implementation of DocumentSnapshot.
// ignore: subtype_of_sealed_class
class MockDocumentSnapshot<T extends Object?> implements DocumentSnapshot<T> {
  final String _id;
  final Map<String, dynamic>? _document;
  final bool _exists;
  final DocumentReference<T> _reference;
  final MockSnapshotMetadata _metadata = MockSnapshotMetadata();
  final Converter<T>? _converter;

  MockDocumentSnapshot(this._reference, this._id,
      Map<String, dynamic>? document, this._exists, this._converter)
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
      if (_converter == null) {
        return deepCopy(_document);
      }
      // Use the converter.
      final typedReference = _reference as MockDocumentReference<T>;
      final nonTypedReference = MockDocumentReference<Map<String, dynamic>>(
          typedReference.firestore as FakeFirebaseFirestore,
          typedReference.path,
          typedReference.id,
          typedReference.root,
          typedReference.docsData,
          typedReference.rootParent,
          typedReference.snapshotStreamControllerRoot,
          /* no converter */ null);
      final jsonSnapshot = MockDocumentSnapshot<Map<String, dynamic>>(
          nonTypedReference,
          _id,
          _document,
          _exists,
          /* no converter */ null);
      return _converter!.fromFirestore(jsonSnapshot, null);
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
  dynamic operator [](field) => get(field);
}
