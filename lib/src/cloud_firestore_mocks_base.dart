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

class MockFirestoreInstance extends Mock implements FirebaseFirestore {
  final _root = <String, dynamic>{};
  final _docsData = <String, dynamic>{};
  final _snapshotStreamControllerRoot = <String, dynamic>{};

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
        _docsData, getSubpath(_snapshotStreamControllerRoot, path));
  }

  @override
  CollectionReference collectionGroup(String collectionId) {
    assert(!collectionId.contains('/'), 'Collection ID should not contain "/"');
    return MockCollectionReference(
      this,
      collectionId,
      buildTreeIncludingCollectionId(_root, _root, collectionId, {}),
      _docsData,
      buildTreeIncludingCollectionId(_snapshotStreamControllerRoot,
          _snapshotStreamControllerRoot, collectionId, {}),
      isCollectionGroup: true,
    );
  }

  @override
  DocumentReference doc(String path) {
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
        _docsData,
        _root,
        getSubpath(_snapshotStreamControllerRoot, path));
  }

  @override
  WriteBatch batch() {
    return MockWriteBatch();
  }

  @override
  Future<T> runTransaction<T>(TransactionHandler<T> transactionHandler,
      {Duration timeout = const Duration(seconds: 30)}) async {
    Transaction transaction = _DummyTransaction();
    final handlerResult = await transactionHandler(transaction);

    // While cloud_firestore's TransactionHandler does not specify the
    // return value type, runTransaction expects returning a map.
    // When TransactionHandler returns void, it returns an empty map.
    // https://github.com/FirebaseExtended/flutterfire/issues/1642
    if (handlerResult is Map<String, dynamic>) {
      handlerResult.values.forEach(_validateTransactionReturnValue);
    }

    return handlerResult ?? {};
  }

  /// Throws PlatformException when the value is not allowed as values of the
  /// return map of runTransaction. The behavior is not documented in Firestore,
  /// but our example/test_driver/cloud_firestore_behaviors.dart verifies at
  /// least the types listed in this function are allowed.
  /// https://firebase.google.com/docs/reference/android/com/google/firebase/functions/HttpsCallableReference#public-taskhttpscallableresult-call-object-data
  void _validateTransactionReturnValue(dynamic value) {
    if (value == null ||
        value is int ||
        value is double ||
        value is bool ||
        value is String ||
        value is DateTime ||
        value is Timestamp ||
        value is GeoPoint ||
        value is Blob) {
      return;
    } else if (value is List) {
      for (final element in value) {
        _validateTransactionReturnValue(element);
      }
      return;
    } else if (value is Map<String, dynamic>) {
      for (final element in value.values) {
        _validateTransactionReturnValue(element);
      }
      return;
    }
    throw PlatformException(
        code: 'error',
        message: 'Invalid argument: Instance of ${value.runtimeType}');
  }

  String dump() {
    final copy = deepCopy(_root);

    // `copy` only contains the categories and sub-categories at this point,
    // no document data. This loop adds each document to the tree.
    for (var doc in _docsData.entries) {
      final docId = doc.key;
      final docProperties = doc.value;
      final docCopy = getSubpath(copy, docId);
      for (var property in docProperties.entries) {
        // In case there is a conflict between a sub-category name and document
        // property, the sub-category takes precedence, meaning the returned
        // json will not return that document property.
        if (!docCopy.containsKey(property.key)) {
          docCopy[property.key] = property.value;
        }
      }
    }

    final encoder = JsonEncoder.withIndent('  ', myEncode);
    final jsonText = encoder.convert(copy);
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

  void _setupFieldValueFactory() {
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
  Transaction delete(DocumentReference documentReference) {
    _foundWrite = true;
    documentReference.delete();
    return this;
  }

  @override
  Transaction update(
      DocumentReference documentReference, Map<String, dynamic> data) {
    _foundWrite = true;
    documentReference.update(data);
    return this;
  }

  @override
  Transaction set(
      DocumentReference documentReference, Map<String, dynamic> data,
      [SetOptions options]) {
    _foundWrite = true;
    documentReference.set(data);
    return this;
  }
}
