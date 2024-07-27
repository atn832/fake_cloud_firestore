import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:rxdart/rxdart.dart';

import 'fake_query_with_parent.dart';
import 'mock_document_change.dart';
import 'mock_query_document_snapshot.dart';
import 'mock_query_snapshot.dart';

/// This class maintains stream controllers for Queries to fire snapshots.
class QuerySnapshotStreamManager {
  static QuerySnapshotStreamManager? _instance;

  factory QuerySnapshotStreamManager() =>
      _instance ??= QuerySnapshotStreamManager._internal();

  QuerySnapshotStreamManager._internal();

  final Map<
          FirebaseFirestore,
          Map<String,
              Map<FakeQueryWithParent, StreamController<QuerySnapshot>>>>
      _streamCache = {};

  final Map<FakeQueryWithParent, QuerySnapshot> _cacheQuerySnapshot = {};

  Future<void> clear() {
    final streamCloseFutures = <Future>[];
    for (final pathToQueryToStreamController in _streamCache.values) {
      for (final queryToStreamController
          in pathToQueryToStreamController.values) {
        for (final streamController in queryToStreamController.values) {
          streamCloseFutures.add(streamController.close());
        }
      }
    }
    _streamCache.clear();
    _cacheQuerySnapshot.clear();
    return Future.wait(streamCloseFutures);
  }

  /// Recursively finds the base collection path.
  String _getBaseCollectionPath(FakeQueryWithParent query) {
    if (query is CollectionReference) {
      return (query as CollectionReference).path;
    } else {
      // In theory retrieveParentPath should stop at the collection reference.
      // So _parentQuery can never be null.
      return _getBaseCollectionPath(query.parentQuery!);
    }
  }

  void register<T>(FakeQueryWithParent query) {
    final firestore = query.firestore;
    if (!_streamCache.containsKey(query.firestore)) {
      _streamCache[firestore] = {};
    }
    final path = _getBaseCollectionPath(query);
    if (!_streamCache[firestore]!.containsKey(path)) {
      _streamCache[query.firestore]![path] = {};
    }
    _streamCache[firestore]![path]!
        .putIfAbsent(query, () => BehaviorSubject<QuerySnapshot<T>>());
  }

  void unregister(FakeQueryWithParent query) {
    final path = _getBaseCollectionPath(query);
    final pathCache = _streamCache[query.firestore]![path];
    if (pathCache == null) {
      return;
    }
    final controller = pathCache.remove(query);
    controller!.close();
  }

  StreamController<QuerySnapshot<T>> getStreamController<T>(
      FakeQueryWithParent query) {
    final path = _getBaseCollectionPath(query);
    final pathCache = _streamCache[query.firestore]![path];
    // Before calling `getStreamController(query)`, one should have called
    // `register(query)` beforehand, so pathCache should never be null.
    assert(pathCache != null);
    final streamController = pathCache![query]!;
    if (streamController is! StreamController<QuerySnapshot<T>>) {
      throw UnimplementedError();
    }
    return streamController;
  }

  Future<void> fireSnapshotUpdate<T>(
    FirebaseFirestore firestore,
    String path, {
    String? id,
  }) async {
    if (!_streamCache.containsKey(firestore)) {
      // Normal. It happens if you try to fire updates before anyone has
      // subscribed to snapshots.
      return;
    }
    final exactPathCache = _streamCache[firestore]![path];
    if (exactPathCache != null && id != null) {
      for (final query in [...exactPathCache.keys]) {
        if (query is! FakeQueryWithParent<T>) {
          // Backward compatibility for queries with different converters.
          await query.get().then(exactPathCache[query]!.add);
          continue;
        }

        final invalidCache = _cacheQuerySnapshot[query] != null &&
            _cacheQuerySnapshot[query] is! QuerySnapshot<T>;
        if (invalidCache) {
          assert(invalidCache,
              'querySnapshotPrior is not null or QuerySnapshot<T>. Got ${_cacheQuerySnapshot[query]}');
          continue;
        }
        final querySnapshotPrior =
            _cacheQuerySnapshot[query] as QuerySnapshot<T>?;

        final querySnapshot = await query.get();
        final docsPrior = querySnapshotPrior?.docs ?? [];
        final docsCurrent = List.of(querySnapshot.docs);
        // Collect change from the whole query documents, whether they be added,
        // deleted or modified.
        final affectedIds = <String>{
          ...docsPrior.map((d) => d.id),
          ...docsCurrent.map((d) => d.id)
        };
        final documentsChange = affectedIds
            .map((id) {
              return _getDocumentChange<T>(
                id: id,
                docsPrior: docsPrior,
                docsCurrent: docsCurrent,
              );
            })
            .whereNotNull()
            .toList();

        final querySnapshotCurrent = MockQuerySnapshot<T>(
          docsCurrent,
          querySnapshot.metadata.isFromCache,
          documentChanges: documentsChange,
        );
        exactPathCache[query]?.add(querySnapshotCurrent);
      }
    }

    // When a document is modified, fire an update on the parent collection.
    if (path.contains('/')) {
      final tokens = path.split('/');
      final parentPath = tokens.sublist(0, tokens.length - 1).join('/');
      await fireSnapshotUpdate<T>(firestore, parentPath, id: id ?? tokens.last);
    }
  }

  /// Returns [DocumentChange] for doc [id] based on the change between [docsPrior] and [docsCurrent].
  DocumentChange<T>? _getDocumentChange<T>({
    required String id,
    required List<QueryDocumentSnapshot<T>> docsPrior,
    required List<QueryDocumentSnapshot<T>> docsCurrent,
  }) {
    final docPriorIndex = docsPrior.indexWhere((element) {
      return element.id == id;
    });
    final docCurrentIndex = docsCurrent.indexWhere((element) {
      return element.id == id;
    });

    if (docCurrentIndex != -1 &&
        docPriorIndex != -1 &&
        !DeepCollectionEquality.unordered().equals(
            (docsCurrent[docCurrentIndex] as MockQueryDocumentSnapshot)
                .rawData(),
            (docsPrior[docPriorIndex] as MockQueryDocumentSnapshot)
                .rawData())) {
      /// Document is modified.
      return MockDocumentChange<T>(
        docsCurrent[docCurrentIndex],
        DocumentChangeType.modified,
        oldIndex: docPriorIndex,
        newIndex: docCurrentIndex,
      );
    } else if (docCurrentIndex != -1 && docPriorIndex == -1) {
      /// Document is added.
      return MockDocumentChange<T>(
        docsCurrent[docCurrentIndex],
        DocumentChangeType.added,
        oldIndex: -1,
        newIndex: docCurrentIndex,
      );
    } else if (docCurrentIndex == -1 && docPriorIndex != -1) {
      /// Document is removed.
      return MockDocumentChange<T>(
        docsPrior[docPriorIndex],
        DocumentChangeType.removed,
        oldIndex: docPriorIndex,
        newIndex: -1,
      );
    }
    return null;
  }

  /// Updates the latest cached [QuerySnapshot] for [query] stored in [_cacheQuerySnapshot].
  void setCacheQuerySnapshot<T>(
    FakeQueryWithParent query,
    QuerySnapshot<T> querySnapshot,
  ) {
    _cacheQuerySnapshot[query] = querySnapshot;
  }
}
