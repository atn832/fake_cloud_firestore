import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import 'fake_query_with_parent.dart';

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

  void clear() {
    for (final pathToQueryToStreamController in _streamCache.values) {
      for (final queryToStreamController
          in pathToQueryToStreamController.values) {
        for (final streamController in queryToStreamController.values) {
          streamController.close();
        }
      }
    }
    _streamCache.clear();
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

  Future<void> fireSnapshotUpdate(
      FirebaseFirestore firestore, String path) async {
    if (!_streamCache.containsKey(firestore)) {
      // Normal. It happens if you try to fire updates before anyone has
      // subscribed to snapshots.
      return;
    }
    final exactPathCache = _streamCache[firestore]![path];
    if (exactPathCache != null) {
      for (final query in exactPathCache.keys.toList()) {
        final streamController = exactPathCache[query];
        if (streamController != null) {
          await query.get().then(streamController.add);
        }
      }
    }

    // When a document is modified, fire an update on the parent collection.
    if (path.contains('/')) {
      final tokens = path.split('/');
      final parentPath = tokens.sublist(0, tokens.length - 1).join('/');
      await fireSnapshotUpdate(firestore, parentPath);
    }
  }
}
