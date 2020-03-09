import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:mockito/mockito.dart';

import 'mock_collection_reference.dart';
import 'mock_document_reference.dart';
import 'mock_field_value_factory_platform.dart';
import 'mock_write_batch.dart';
import 'util.dart';

class MockFirestoreInstance extends Mock implements Firestore {
  Map<String, dynamic> _root = Map();
  Map<String, dynamic> _snapshotStreamControllerRoot = Map();

  /// Saved documents' full paths from root. For example:
  /// 'users/abc/friends/foo'
  final Set<String> _savedDocumentPaths = <String>{};
  MockFirestoreInstance() {
    _setupFieldValueFactory();
  }

  @override
  CollectionReference collection(String path) {
    var segments = path.split('/');
    assert(segments.length % 2 == 1,
        'Invalid document reference. Collection references must have an odd number of segments');
    return MockCollectionReference(this, path, getSubpath(_root, path),
        getSubpath(_snapshotStreamControllerRoot, path));
  }

  @override
  DocumentReference document(String path) {
    var segments = path.split('/');
    // The actual behavior of Firestore for an invalid number of segments
    // differs by platforms. This library imitates it with assert.
    // https://github.com/atn832/cloud_firestore_mocks/issues/30
    assert(segments.length % 2 == 0,
        'Invalid document reference. Document references must have an even number of segments');
    final documentId = segments.last;
    return MockDocumentReference(
        this,
        path,
        documentId,
        getSubpath(_root, path),
        _root,
        getSubpath(_snapshotStreamControllerRoot, path));
  }

  WriteBatch batch() {
    return MockWriteBatch();
  }

  String dump() {
    JsonEncoder encoder = JsonEncoder.withIndent('  ', myEncode);
    final jsonText = encoder.convert(_root);
    return jsonText;
  }

  void saveDocument(String path) {
    _savedDocumentPaths.add(path);
  }

  bool hasSavedDocument(String path) {
    return _savedDocumentPaths.contains(path);
  }

  bool removeSavedDocument(String path) {
    return _savedDocumentPaths.remove(path);
  }

  _setupFieldValueFactory() {
    FieldValueFactoryPlatform.instance = MockFieldValueFactoryPlatform();
  }
}
