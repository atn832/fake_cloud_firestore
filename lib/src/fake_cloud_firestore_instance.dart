import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as firestore_interface;
import 'package:fake_firebase_security_rules/fake_firebase_security_rules.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

import 'mock_collection_reference.dart';
import 'mock_document_reference.dart';
import 'mock_field_value_factory_platform.dart';
import 'mock_write_batch.dart';
import 'util.dart';

const allowAllDescription = '''service cloud.firestore {
  match /{document=**} {
    allow read, write;
  }
}''';

class FakeFirebaseFirestore implements FirebaseFirestore {
  final _root = <String, dynamic>{};
  final _docsData = <String, dynamic>{};
  final _snapshotStreamControllerRoot = <String, dynamic>{};

  /// Saved documents' full paths from root. For example:
  /// 'users/abc/friends/foo'
  final Set<String> _savedDocumentPaths = <String>{};

  // Auth objects used to test the security of each request.
  final Stream<Map<String, dynamic>?> authObject;
  final FakeFirebaseSecurityRules securityRules;

  FakeFirebaseFirestore(
      {Stream<Map<String, dynamic>?>? authObject,
      FakeFirebaseSecurityRules? securityRules})
      : authObject =
            authObject ?? BehaviorSubject<Map<String, dynamic>?>.seeded(null),
        securityRules =
            securityRules ?? FakeFirebaseSecurityRules(allowAllDescription) {
    _setupFieldValueFactory();
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    final segments = path.split('/');
    assert(segments.length % 2 == 1,
        'Invalid document reference. Collection references must have an odd number of segments');
    return MockCollectionReference(this, path, getSubpath(_root, path),
        _docsData, getSubpath(_snapshotStreamControllerRoot, path));
  }

  @override
  CollectionReference<Map<String, dynamic>> collectionGroup(
      String collectionId) {
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
  DocumentReference<Map<String, dynamic>> doc(String path) {
    final segments = path.split('/');
    // The actual behavior of Firestore for an invalid number of segments
    // differs by platforms. This library imitates it with assert.
    // https://github.com/atn832/fake_cloud_firestore/issues/30
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
        getSubpath(_snapshotStreamControllerRoot, path),
        null);
  }

  @override
  WriteBatch batch() {
    return MockWriteBatch();
  }

  @override
  Future<T> runTransaction<T>(TransactionHandler<T> transactionHandler,
      {Duration timeout = const Duration(seconds: 30),
      int maxAttempts = 5}) async {
    Transaction transaction = _DummyTransaction();
    return await transactionHandler(transaction);
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

  Future<void> maybeThrowSecurityException(String path, Method method) async {
    // make request object with auth.
    final latestUser = await authObject.first;
    if (!securityRules.isAllowed(path, method, variables: {
      'request': {'auth': latestUser}
    })) {
      throw Exception('Not allowed');
    }
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

  // Required because FirebaseFirestore' == expects dynamic, while Mock's == expects an object.
  @override
  bool operator ==(dynamic other) => identical(this, other);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Dummy transaction object that sequentially executes the operations without
/// any rollback upon any failures. Good enough to run with tests.
class _DummyTransaction implements Transaction {
  bool _foundWrite = false;

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
      DocumentReference<T> documentReference) {
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
  Transaction set<T>(DocumentReference<T> documentReference, T data,
      [SetOptions? options]) {
    _foundWrite = true;
    documentReference.set(data);
    return this;
  }
}
