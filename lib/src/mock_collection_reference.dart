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
  FirebaseFirestore get firestore => _firestore;

  @override
  String get path => _path;

  @override
  DocumentReference get parent {
    final segments = _path.split('/');
    final segmentLength = segments.length;
    if (segmentLength > 1) {
      final parentSegments = segments.sublist(0, segmentLength - 1);
      final parentPath = parentSegments.join('/');
      return _firestore.doc(parentPath);
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
  Future<QuerySnapshot> get([GetOptions getOptions]) async {
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
    final documentOrCollectionEntries = node.entries;
    if (pathSegments.last == _collectionId) {
      final documentReferences = documentOrCollectionEntries
          .map((entry) => _documentReference(path, entry.key, node))
          .where((documentReference) =>
              docsData.keys.contains(documentReference.path));
      for (final documentReference in documentReferences) {
        result.add(MockDocumentSnapshot(
          documentReference,
          documentReference.id,
          docsData[documentReference.path],
          _firestore.hasSavedDocument(documentReference.path),
        ));
      }
    }
    for (final entry in documentOrCollectionEntries) {
      final segment = entry.key;
      final subCollection = entry.value;
      _buildDocumentsForCollectionGroup(
        subCollection,
        result,
        path.isEmpty ? segment : '$path/${segment}',
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
  DocumentReference doc([String path]) {
    final id = (path == null) ? _generateAutoId() : path;
    return _documentReference(_path, id, root);
  }

  DocumentReference _documentReference(
      String collectionFullPath, String id, Map<String, dynamic> root) {
    final fullPath = [collectionFullPath, id].join('/');
    return MockDocumentReference(
      firestore,
      fullPath,
      id,
      getSubpath(root, id),
      docsData,
      root,
      getSubpath(snapshotStreamControllerRoot, id),
    );
  }

  @override
  Future<DocumentReference> add(Map<String, dynamic> data) async {
    final documentReference = doc();
    await documentReference.update(data);

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
    snapshotStreamController.add(await get());
  }
}
