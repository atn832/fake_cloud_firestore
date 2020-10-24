import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:mockito/mockito.dart';

import 'cloud_firestore_mocks_base.dart';
import 'mock_collection_reference.dart';
import 'mock_document_snapshot.dart';
import 'mock_field_value_platform.dart';
import 'mock_query.dart';
import 'util.dart';

class MockDocumentReference extends Mock implements DocumentReference {
  final String _id;
  final Map<String, dynamic> root;
  final Map<String, dynamic> docsData;
  final Map<String, dynamic> rootParent;
  final Map<String, dynamic> snapshotStreamControllerRoot;
  final MockFirestoreInstance _firestore;

  /// Path from the root to this document. For example "users/USER0004/friends/FRIEND001"
  final String _path;

  MockDocumentReference(this._firestore, this._path, this._id, this.root,
      this.docsData, this.rootParent, this.snapshotStreamControllerRoot);

  // ignore: unused_field
  final DocumentReferencePlatform _delegate = null;

  @override
  FirebaseFirestore get firestore => _firestore;

  @override
  String get id => _id;

  @override
  String get path => _path;

  @override
  CollectionReference get parent {
    final segments = _path.split('/');
    // For any document reference, segment length is more than 1
    final segmentLength = segments.length;
    final parentSegments = segments.sublist(0, segmentLength - 1);
    final parentPath = parentSegments.join('/');
    return _firestore.collection(parentPath);
  }

  @override
  CollectionReference collection(String collectionPath) {
    final path = [_path, collectionPath].join('/');
    return MockCollectionReference(
        _firestore,
        path,
        getSubpath(root, collectionPath),
        docsData,
        getSubpath(snapshotStreamControllerRoot, collectionPath));
  }

  @override
  Future<void> update(Map<String, dynamic> data) {
    validateDocumentValue(data);
    // Copy data so that subsequent change to `data` should not affect the data
    // stored in mock document.
    final copy = deepCopy(data);
    copy.forEach((key, value) {
      // document == root if key is not a composite key
      final document = _findNestedDocumentToUpdate(key);
      if (document != docsData[_path]) {
        // Example, key: 'foo.bar.username', get 'username' field
        key = key.split('.').last;
      }
      _applyValues(document, key, value);
    });
    _firestore.saveDocument(path);
    QuerySnapshotStreamManager().fireSnapshotUpdate(path);

    return Future.value(null);
  }

  void _applyValues(Map<String, dynamic> document, String key, dynamic value) {
    // Handle the recursive case.
    if (value is Map<String, dynamic>) {
      if (!document.containsKey(key)) {
        document[key] = <String, dynamic>{};
      }
      value.forEach((subkey, subvalue) {
        _applyValues(document[key], subkey, subvalue);
      });
      return;
    }
    // TODO: support handling values in lists.

    // Handle values.
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
  }

  Map<String, dynamic> _findNestedDocumentToUpdate(String key) {
    final compositeKeyElements = key.split('.');
    if (!docsData.containsKey(_path)) {
      docsData[_path] = <String, dynamic>{};
    }
    if (compositeKeyElements.length == 1) {
      // This is not a composite key
      return docsData[_path];
    }

    var document = docsData[_path];

    // For N elements, iterate until N-1 element.
    // For example, key: "foo.bar.baz", this method return the document pointed by
    // 'foo.bar'. The document will be updated by the caller on 'baz' field
    final keysToIterate =
        compositeKeyElements.sublist(0, compositeKeyElements.length - 1);
    for (final keyElement in keysToIterate) {
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
  Future<void> set(Map<String, dynamic> data, [SetOptions setOptions]) {
    final merge = setOptions?.merge ?? false;
    if (!merge && docsData.containsKey(_path)) {
      docsData[_path].clear();
    }
    return update(data);
  }

  @override
  Future<DocumentSnapshot> get([GetOptions getOptions]) {
    return Future.value(
        MockDocumentSnapshot(this, _id, docsData[_path], _exists()));
  }

  bool _exists() {
    return _firestore.hasSavedDocument(_path);
  }

  @override
  Future<void> delete() {
    rootParent.remove(id);
    _firestore.removeSavedDocument(path);
    QuerySnapshotStreamManager().fireSnapshotUpdate(path);
    return Future.value();
  }

  @override
  Stream<DocumentSnapshot> snapshots({bool includeMetadataChanges = false}) {
    return Stream.value(
        MockDocumentSnapshot(this, _id, docsData[_path], _exists()));
  }

  @override
  bool operator ==(dynamic o) =>
      o is DocumentReference && o.firestore == _firestore && o.path == _path;

  @override
  int get hashCode => _path.hashCode + _firestore.hashCode;

  Map<String, dynamic> toJson() =>
      {
        'type': 'DocumentReference',
        'path': _path,
      };
}
