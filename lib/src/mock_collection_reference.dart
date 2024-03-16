import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fake_cloud_firestore/src/fake_aggregate_query.dart';
import 'package:fake_cloud_firestore/src/fake_query_with_parent.dart';

import 'converter.dart';
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
    final snapshot = MockQuerySnapshot<T>(
      (await Future.wait(futureDocs))
          .where((snapshot) =>
              _firestore.hasSavedDocument(snapshot.reference.path))
          .toList(),
      options?.source == Source.cache,
    );
    QuerySnapshotStreamManager().setCacheQuerySnapshot(this, snapshot);
    return snapshot;
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
    await QuerySnapshotStreamManager()
        .fireSnapshotUpdate<T>(firestore, path, id: documentReference.id);
    return documentReference;
  }

  // Required because Firestore' == expects dynamic, while Mock's == expects an object.
  @override
  bool operator ==(Object other) => identical(this, other);

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

  @override
  AggregateQuery aggregate(
    AggregateField aggregateField1, [
    AggregateField? aggregateField2,
    AggregateField? aggregateField3,
    AggregateField? aggregateField4,
    AggregateField? aggregateField5,
    AggregateField? aggregateField6,
    AggregateField? aggregateField7,
    AggregateField? aggregateField8,
    AggregateField? aggregateField9,
    AggregateField? aggregateField10,
    AggregateField? aggregateField11,
    AggregateField? aggregateField12,
    AggregateField? aggregateField13,
    AggregateField? aggregateField14,
    AggregateField? aggregateField15,
    AggregateField? aggregateField16,
    AggregateField? aggregateField17,
    AggregateField? aggregateField18,
    AggregateField? aggregateField19,
    AggregateField? aggregateField20,
    AggregateField? aggregateField21,
    AggregateField? aggregateField22,
    AggregateField? aggregateField23,
    AggregateField? aggregateField24,
    AggregateField? aggregateField25,
    AggregateField? aggregateField26,
    AggregateField? aggregateField27,
    AggregateField? aggregateField28,
    AggregateField? aggregateField29,
    AggregateField? aggregateField30,
  ]) {
    return FakeAggregateQuery(this, [
      aggregateField1,
      aggregateField2,
      aggregateField3,
      aggregateField4,
      aggregateField5,
      aggregateField6,
      aggregateField7,
      aggregateField8,
      aggregateField9,
      aggregateField10,
      aggregateField11,
      aggregateField12,
      aggregateField13,
      aggregateField14,
      aggregateField15,
      aggregateField16,
      aggregateField17,
      aggregateField18,
      aggregateField19,
      aggregateField20,
      aggregateField21,
      aggregateField22,
      aggregateField23,
      aggregateField24,
      aggregateField25,
      aggregateField26,
      aggregateField27,
      aggregateField28,
      aggregateField29,
      aggregateField30,
    ]);
  }
}
