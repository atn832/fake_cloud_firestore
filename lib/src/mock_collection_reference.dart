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
  final Map<String, dynamic> docsData;
  final Map<String, dynamic> snapshotStreamControllerRoot;
  final MockFirestoreInstance _firestore;
  final bool _isCollectionGroup;

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

  MockCollectionReference(this._firestore, this._path, this.root, this.docsData,
      this.snapshotStreamControllerRoot,
      {isCollectionGroup = false})
      : _isCollectionGroup = isCollectionGroup,
        super();

  @override
  Firestore get firestore => _firestore;

  @override
  String get path => _path;

  @override
  DocumentReference parent() {
    final segments = _path.split('/');
    final segmentLength = segments.length;
    if (segmentLength > 1) {
      final parentSegments = segments.sublist(0, segmentLength - 1);
      final parentPath = parentSegments.join('/');
      return _firestore.document(parentPath);
    } else {
      // This is not a subcollection, returning null
      // https://firebase.google.com/docs/reference/js/firebase.firestore.CollectionReference
      return null;
    }
  }

  String get _collectionId {
    assert(_isCollectionGroup, 'alias for only CollectionGroup');
    return _path;
  }

  @override
  Future<QuerySnapshot> getDocuments(
      {Source source = Source.serverAndCache}) async {
    var documents = <MockDocumentSnapshot>[];
    if (_isCollectionGroup) {
      documents = _buildDocumentsForCollectionGroup(root, []);
    } else {
      documents = root.entries.map((entry) {
        MockDocumentReference documentReference =
            _documentReference(_path, entry.key, root);
        return MockDocumentSnapshot(
          documentReference,
          entry.key,
          docsData[documentReference.path],
          _firestore.hasSavedDocument(documentReference.path),
        );
      }).toList();
    }
    return MockSnapshot(
      documents
          .where((snapshot) =>
              _firestore.hasSavedDocument(snapshot.reference.path))
          .toList(),
    );
  }

  List<MockDocumentSnapshot> _buildDocumentsForCollectionGroup(
      Map<String, dynamic> node, List<MockDocumentSnapshot> result,
      [String path = '']) {
    final pathSegments = path.split('/');
    final documentOrCollectionEntries =
        node.entries.where((entry) => entry.value is Map<String, dynamic>);
    if (pathSegments.last == _collectionId) {
      final documentReferences = documentOrCollectionEntries
          .map((entry) => _documentReference(path, entry.key, node))
          .where((documentReference) =>
              docsData.keys.contains(documentReference.path));
      for (final documentReference in documentReferences) {
        result.add(MockDocumentSnapshot(
          documentReference,
          documentReference.documentID,
          docsData[documentReference.path],
          _firestore.hasSavedDocument(documentReference.path),
        ));
      }
    }
    for (final entry in documentOrCollectionEntries) {
      _buildDocumentsForCollectionGroup(
        entry.value,
        result,
        path.isEmpty ? entry.key : '$path/${entry.key}',
      );
    }
    return result;
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
    return _documentReference(_path, documentId, root);
  }

  DocumentReference _documentReference(
      String collectionFullPath, String documentId, Map<String, dynamic> root) {
    final fullPath = [collectionFullPath, documentId].join('/');
    return MockDocumentReference(
      firestore,
      fullPath,
      documentId,
      getSubpath(root, documentId),
      docsData,
      root,
      getSubpath(snapshotStreamControllerRoot, documentId),
    );
  }

  @override
  Future<DocumentReference> add(Map<String, dynamic> data) async {
    final documentReference = document();
    await documentReference.updateData(data);

    _firestore.saveDocument(documentReference.path);
    QuerySnapshotStreamManager().fireSnapshotUpdate(path);
    await fireSnapshotUpdate();
    return documentReference;
  }

  @override
  Stream<QuerySnapshot> snapshots({bool includeMetadataChanges = false}) {
    Future(() {
      fireSnapshotUpdate();
    });
    return snapshotStreamController.stream;
  }

  Future<void> fireSnapshotUpdate() async {
    snapshotStreamController.add(await getDocuments());
  }
}
