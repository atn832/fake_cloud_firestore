import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fake_cloud_firestore/src/fake_query_with_parent.dart';

import 'converter.dart';
import 'mock_document_change.dart';
import 'mock_document_reference.dart';
import 'mock_query.dart';
import 'mock_query_snapshot.dart';
import 'query_snapshot_stream_manager.dart';
import 'util.dart';

// ignore: subtype_of_sealed_class
class MockCollectionReference<T extends Object?> extends MockQuery<T>
    implements CollectionReference<T> {
  final Map<String, dynamic> root;
  final Map<String, dynamic> docsData;
  final Map<String, dynamic> snapshotStreamControllerRoot;
  final FakeFirebaseFirestore _firestore;
  final bool _isCollectionGroup;
  final Converter<T>? _converter;

  /// Path from the root to this collection. For example "users/USER0004/friends"
  final String _path;

  MockCollectionReference(
    this._firestore,
    this._path,
    this.root,
    this.docsData,
    this.snapshotStreamControllerRoot, {
    isCollectionGroup = false,
    converter,
  })  : _isCollectionGroup = isCollectionGroup,
        _converter = converter,
        super(null, null);

  @override
  FirebaseFirestore get firestore => _firestore;

  @override
  String get path => _path;

  @override
  DocumentReference<Map<String, dynamic>>? get parent {
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
  Future<QuerySnapshot<T>> get([GetOptions? options]) async {
    List<Future<DocumentSnapshot<T>>> futureDocs;
    if (_isCollectionGroup) {
      futureDocs = _buildDocumentsForCollectionGroup(root, []);
    } else {
      futureDocs = root.entries.map((entry) {
        final documentReference = _documentReference(_path, entry.key, root);
        return documentReference.get();
      }).toList();
    }
    final snapshots = await Future.wait(futureDocs);
    return MockQuerySnapshot<T>(
      snapshots.where((element) {
        return _firestore.hasSavedDocument(element.reference.path);
      }).toList(),
      options?.source == Source.cache,
      documentChanges: snapshots.mapIndexed((index, e) {
        return MockDocumentChange<T>(e, DocumentChangeType.added, oldIndex: -1, newIndex: index);
      }).toList(),
    );
  }

  List<Future<DocumentSnapshot<T>>> _buildDocumentsForCollectionGroup(
      Map<String, dynamic> node, List<Future<DocumentSnapshot<T>>> result,
      [String path = '']) {
    final pathSegments = path.split('/');
    final documentOrCollectionEntries = node.entries;
    if (pathSegments.last == _collectionId) {
      final documentReferences = documentOrCollectionEntries
          .map((entry) => _documentReference(path, entry.key, node))
          .where((documentReference) =>
              docsData.keys.contains(documentReference.path));
      for (final documentReference in documentReferences) {
        result.add(documentReference.get());
      }
    }
    for (final entry in documentOrCollectionEntries) {
      final segment = entry.key;

      if (entry.value == null) continue;

      final subCollection = entry.value;
      _buildDocumentsForCollectionGroup(
        subCollection,
        result,
        path.isEmpty ? segment : '$path/$segment',
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
  DocumentReference<T> doc([String? path]) {
    final id = (path == null) ? _generateAutoId() : path;
    return _documentReference(_path, id, root);
  }

  DocumentReference<T> _documentReference(
      String collectionFullPath, String id, Map<String, dynamic> root) {
    final fullPath = [collectionFullPath, id].join('/');
    final rawDocumentReference = MockDocumentReference<T>(
      _firestore,
      fullPath,
      id,
      getSubpath(root, id),
      docsData,
      root,
      getSubpath(snapshotStreamControllerRoot, id),
      null,
    );
    if (_converter == null) {
      // Since there is no converter, we know that T is Map<String, dynamic>.
      return rawDocumentReference;
    }
    // Convert.
    final convertedDocumentReference = rawDocumentReference.withConverter(
        fromFirestore: _converter!.fromFirestore,
        toFirestore: _converter!.toFirestore);
    return convertedDocumentReference;
  }

  @override
  Future<DocumentReference<T>> add(T data) async {
    final documentReference = doc();
    await documentReference.set(data);
    _firestore.saveDocument(documentReference.path);
    await QuerySnapshotStreamManager().fireSnapshotUpdate<T>(firestore, path, id: documentReference.id);
    return documentReference;
  }

  // Required because Firestore' == expects dynamic, while Mock's == expects an object.
  @override
  bool operator ==(dynamic other) => identical(this, other);

  @override
  String get id => _isCollectionGroup ? _path : _path.split('/').last;

  @override
  CollectionReference<R> withConverter<R extends Object?>({
    required FromFirestore<R> fromFirestore,
    required ToFirestore<R> toFirestore,
  }) =>
      MockCollectionReference<R>(
          _firestore, _path, root, docsData, snapshotStreamControllerRoot,
          isCollectionGroup: _isCollectionGroup,
          converter: Converter(fromFirestore, toFirestore));

  @override
  FakeQueryWithParent? get parentQuery => null;
}
