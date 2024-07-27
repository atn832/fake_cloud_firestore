import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/src/mock_snapshot_metadata.dart';
import 'package:fake_cloud_firestore/src/util.dart';

// Intentional implementation of DocumentSnapshot.
// ignore: subtype_of_sealed_class
class MockDocumentSnapshot<T extends Object?> implements DocumentSnapshot<T> {
  final String _id;
  final Map<String, dynamic>? _rawDocument;
  final T? _convertedDocument;
  final bool _exists;
  final DocumentReference<T> _reference;
  final MockSnapshotMetadata _metadata;
  final bool _converted;

  MockDocumentSnapshot(
    this._reference,
    this._id,
    Map<String, dynamic>? rawDocument,
    this._convertedDocument,
    this._converted,
    this._exists,
    bool _isFromCache,
  )   : _rawDocument = deepCopy(rawDocument),
        _metadata = MockSnapshotMetadata(isFromCache: _isFromCache);

  @override
  String get id => _id;

  @override
  dynamic get(dynamic key) {
    if (_isCompositeKey(key)) {
      return _getCompositeKeyValue(key);
    }
    if (!_exists || _rawDocument?.containsKey(key) != true) {
      throw StateError(!_exists
          ? 'Cannot get field if DataSnapshot does not exist.'
          : 'Cannot get field that does not exist');
    }
    return _rawDocument?[key];
  }

  @override
  T? data() {
    if (_exists) {
      if (!_converted) {
        return deepCopy(_rawDocument);
      }
      return _convertedDocument;
    } else {
      return null;
    }
  }

  Map<String, dynamic>? rawData() {
    return _rawDocument;
  }

  @override
  bool get exists => _exists;

  @override
  DocumentReference<T> get reference => _reference;

  @override
  SnapshotMetadata get metadata => _metadata;

  bool _isCompositeKey(dynamic key) {
    if (key is String) {
      return key.contains('.');
    } else if (key is FieldPath) {
      return true;
    } else {
      throw ArgumentError(
          'key must be String or FieldPath but found ${key.runtimeType}');
    }
  }

  dynamic _getCompositeKeyValue(dynamic key) {
    final compositeKeyElements =
        key is String ? key.split('.') : (key as FieldPath).components;
    dynamic value = _rawDocument!;
    for (final keyElement in compositeKeyElements) {
      if (!(value is Map) || !value.containsKey(keyElement)) {
        throw StateError('Cannot get field that does not exist');
      }
      value = value[keyElement];
    }
    return value;
  }

  @override
  dynamic operator [](field) => get(field);
}
