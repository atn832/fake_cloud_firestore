import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:mockito/mockito.dart';

import 'cloud_firestore_mocks_base.dart';
import 'mock_collection_reference.dart';
import 'mock_document_snapshot.dart';
import 'mock_field_value_platform.dart';
import 'util.dart';

class MockDocumentReference extends Mock implements DocumentReference {
  final String _documentId;
  final Map<String, dynamic> root;
  final Map<String, dynamic> rootParent;
  final Map<String, dynamic> snapshotStreamControllerRoot;
  final MockFirestoreInstance _firestore;

  /// Path from the root to this document. For example "users/USER0004/friends/FRIEND001"
  final String _path;

  MockDocumentReference(this._firestore, this._path, this._documentId,
      this.root, this.rootParent, this.snapshotStreamControllerRoot);

  // ignore: unused_field
  final DocumentReferencePlatform _delegate = null;

  @override
  String get documentID => _documentId;

  @override
  String get path => _path;

  @override
  CollectionReference collection(String collectionPath) {
    final path = [_path, collectionPath].join('/');
    return MockCollectionReference(
        _firestore,
        path,
        getSubpath(root, collectionPath),
        getSubpath(snapshotStreamControllerRoot, collectionPath));
  }

  @override
  Future<void> updateData(Map<String, dynamic> data) {
    validateDocumentValue(data);
    data.forEach((key, value) {
      // document == root if key is not a composite key
      final document = _findNestedDocumentToUpdate(key);
      if (document != root) {
        // Example, key: 'foo.bar.username', get 'username' field
        key = key.split('.').last;
      }
      if (value is FieldValue) {
        final valueDelegate = FieldValuePlatform.getDelegate(value);
        final fieldValuePlatform = valueDelegate as MockFieldValuePlatform;
        final fieldValue = fieldValuePlatform.value;
        fieldValue.updateDocument(document, key);
      } else if (value is DateTime) {
        document[key] = Timestamp.fromDate(value);
      } else {
        document[key] = value;
      }
    });
    _firestore.saveDocument(path);
    return Future.value(null);
  }

  Map<String, dynamic> _findNestedDocumentToUpdate(String key) {
    final compositeKeyElements = key.split('.');
    if (compositeKeyElements.length == 1) {
      // This is not a composite key
      return root;
    }

    Map<String, dynamic> document = root;

    // For N elements, iterate until N-1 element.
    // For example, key: "foo.bar.baz", this method return the document pointed by
    // 'foo.bar'. The document will be updated by the caller on 'baz' field
    final keysToIterate =
        compositeKeyElements.sublist(0, compositeKeyElements.length - 1);
    for (String keyElement in keysToIterate) {
      if (!document.containsKey(keyElement) || !(document[keyElement] is Map)) {
        document[keyElement] = <String, dynamic>{};
        document = document[keyElement];
      } else {
        document = document[keyElement] as Map<String, dynamic>;
      }
    }
    return document;
  }

  @override
  Future<void> setData(Map<String, dynamic> data, {bool merge = false}) {
    if (!merge) {
      root.clear();
    }
    return updateData(data);
  }

  @override
  Future<DocumentSnapshot> get({Source source = Source.serverAndCache}) {
    return Future.value(
        MockDocumentSnapshot(this, _documentId, _deepCopy(root), _exists()));
  }

  bool _exists() {
    return _firestore.hasSavedDocument(_path);
  }

  @override
  Future<void> delete() {
    rootParent.remove(documentID);
    _firestore.removeSavedDocument(path);
    return Future.value();
  }

  @override
  Stream<DocumentSnapshot> snapshots({bool includeMetadataChanges = false}) {
    return Stream.value(
        MockDocumentSnapshot(this, _documentId, root, _exists()));
  }

  static Map<String, dynamic> _deepCopy(Map<String, dynamic> fromMap) {
    final toMap = <String, dynamic>{};

    fromMap.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        toMap[key] = _deepCopy(value);
      } else if (value is List) {
        toMap[key] = List.from(value);
      } else {
        toMap[key] = value;
      }
    });

    return toMap;
  }
}

/// Throws ArgumentError when the value is not a Cloud Firestore's supported
/// data types.
/// https://firebase.google.com/docs/firestore/manage-data/data-types
void validateDocumentValue(dynamic value) {
  if (value is bool || // Boolean
      value is Blob || // Bytes
      value is DateTime ||
      value is Timestamp ||
      value is double || // Floating-point number
      value is GeoPoint || // Geographical point
      value is int ||
      value == null ||
      value is DocumentReference ||
      value is String) {
    // supported data types
    return;
  } else if (value is List) {
    for (final element in value) {
      validateDocumentValue(element);
    }
    return;
  } else if (value is Map<String, dynamic>) {
    for (final element in value.values) {
      validateDocumentValue(element);
    }
    return;
  }
  throw ArgumentError.value(value);
}
