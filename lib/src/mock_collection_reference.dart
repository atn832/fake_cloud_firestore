import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';

import 'mock_document_reference.dart';
import 'mock_document_snapshot.dart';
import 'mock_query.dart';
import 'mock_snapshot.dart';
import 'util.dart';

const snapshotsStreamKey = '_snapshots';

class MockCollectionReference extends MockQuery implements CollectionReference {
  final Map<String, dynamic> root;
  final Map<String, dynamic> snapshotStreamControllerRoot;
  final MockFirestoreInstance _firestore;

  /// Path from the root to this collection. For example "users/USER0004/friends"
  final String _path;

  // ignore: unused_field
  final CollectionReferencePlatform _delegate = null;

  StreamController<QuerySnapshot> get snapshotStreamController {
    if (!snapshotStreamControllerRoot.containsKey(snapshotsStreamKey)) {
      snapshotStreamControllerRoot[snapshotsStreamKey] =
          StreamController<QuerySnapshot>.broadcast();
    }
    return snapshotStreamControllerRoot[snapshotsStreamKey];
  }

  MockCollectionReference(
      this._firestore, this._path, this.root, this.snapshotStreamControllerRoot)
      : super();

  @override
  Future<QuerySnapshot> getDocuments(
      {Source source = Source.serverAndCache}) async {
    final documents = root.entries
        .map((entry) {
          MockDocumentReference documentReference = _documentReference(
              _firestore, _path, entry.key, root, snapshotStreamControllerRoot);
          return MockDocumentSnapshot(documentReference, entry.key, entry.value,
              _firestore.hasSavedDocument(documentReference.path));
        })
        .where(
            (snapshot) => _firestore.hasSavedDocument(snapshot.reference.path))
        .toList();
    return MockSnapshot(documents);
  }

  static final Random _random = Random();
  static final String _autoIdCharacters =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  static String _generateAutoId() {
    final maxIndex = _autoIdCharacters.length - 1;
    final autoId = List<int>.generate(20, (_) => _random.nextInt(maxIndex))
        .map((i) => _autoIdCharacters[i])
        .join();
    return autoId;
  }

  @override
  DocumentReference document([String path]) {
    final documentId = (path == null) ? _generateAutoId() : path;
    return _documentReference(
        _firestore, _path, documentId, root, snapshotStreamControllerRoot);
  }

  static DocumentReference _documentReference(
      MockFirestoreInstance firestore,
      String collectionFullPath,
      String documentId,
      Map<String, dynamic> root,
      Map<String, dynamic> snapshotStreamControllerRoot) {
    final fullPath = [collectionFullPath, documentId].join('/');
    return MockDocumentReference(
        firestore,
        fullPath,
        documentId,
        getSubpath(root, documentId),
        root,
        getSubpath(snapshotStreamControllerRoot, documentId));
  }

  @override
  Future<DocumentReference> add(Map<String, dynamic> data) {
    validateDocumentValue(data);
    final dataCopy = deepCopy(data);
    final childId = _generateAutoId();
    final keysWithDateTime = data.keys.where((key) => data[key] is DateTime);
    for (final key in keysWithDateTime) {
      dataCopy[key] = Timestamp.fromDate(data[key]);
    }
    root[childId] = dataCopy;

    final documentReference = document(childId);
    _firestore.saveDocument(documentReference.path);

    fireSnapshotUpdate();
    return Future.value(documentReference);
  }

  @override
  Stream<QuerySnapshot> snapshots({bool includeMetadataChanges = false}) {
    Future(() {
      fireSnapshotUpdate();
    });
    return snapshotStreamController.stream;
  }

  fireSnapshotUpdate() {
    final documents = root.entries.map((entry) {
      final documentReference = document(entry.key);
      return MockDocumentSnapshot(documentReference, entry.key, entry.value,
          _firestore.hasSavedDocument(documentReference.path));
    }).toList();
    snapshotStreamController.add(MockSnapshot(documents));
  }
}
