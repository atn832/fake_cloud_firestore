import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as firestore_interface;
import 'package:flutter/services.dart';
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
    final segments = path.split('/');
    assert(segments.length % 2 == 1,
        'Invalid document reference. Collection references must have an odd number of segments');
    return MockCollectionReference(this, path, getSubpath(_root, path),
        getSubpath(_snapshotStreamControllerRoot, path));
  }

  @override
  DocumentReference document(String path) {
    final segments = path.split('/');
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

  @override
  WriteBatch batch() {
    return MockWriteBatch();
  }

  @override
  Future<Map<String, dynamic>> runTransaction(
      TransactionHandler transactionHandler,
      {Duration timeout = const Duration(seconds: 5)}) async {
    Transaction transaction = _DummyTransaction();
    final handlerResult = await transactionHandler(transaction);

    // While cloud_firestore's TransactionHandler does not specify the
    // return value type, runTransaction expects returning a map.
    // When TransactionHandler returns void, it returns an empty map.
    // https://github.com/FirebaseExtended/flutterfire/issues/1642
    return handlerResult ?? {};
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
    firestore_interface.FieldValueFactoryPlatform.instance =
        MockFieldValueFactoryPlatform();
  }
}

/// Dummy transaction object that sequentially executes the operations without
/// any rollback upon any failures. Good enough to run with tests.
class _DummyTransaction implements Transaction {
  bool _foundWrite = false;

  @override
  Future<DocumentSnapshot> get(DocumentReference documentReference) {
    if (_foundWrite) {
      throw PlatformException(
          code: '3',
          message:
              'Firestore transactions require all reads to be executed before all writes');
    }
    return documentReference.get();
  }

  @override
  Future<void> delete(DocumentReference documentReference) {
    _foundWrite = true;
    return documentReference.delete();
  }

  @override
  Future<void> update(
      DocumentReference documentReference, Map<String, dynamic> data) {
    _foundWrite = true;
    return documentReference.updateData(data);
  }

  @override
  Future<void> set(
      DocumentReference documentReference, Map<String, dynamic> data) {
    _foundWrite = true;
    return documentReference.setData(data);
  }
}
