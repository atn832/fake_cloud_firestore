import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'fake_query_with_parent.dart';

/// This class maintains stream controllers for Queries to fire snapshots.
class QuerySnapshotStreamManager {
  static QuerySnapshotStreamManager? _instance;

  factory QuerySnapshotStreamManager() =>
      _instance ??= QuerySnapshotStreamManager._internal();

  QuerySnapshotStreamManager._internal();
  final Map<String, Map<FakeQueryWithParent, StreamController<QuerySnapshot>>>
      _streamCache = {};

  void clear() {
    for (final queryToStreamController in _streamCache.values) {
      for (final streamController in queryToStreamController.values) {
        streamController.close();
      }
    }
    _streamCache.clear();
  }

  /// Recursively finds the base collection path.
  String _getBaseCollectionPath(FakeQueryWithParent query) {
    // In theory retrieveParentPath should stop at the collection reference.
    // So _parentQuery can never be null.
    assert(query.parentQuery != null);
    if (query.parentQuery is CollectionReference) {
      return (query.parentQuery as CollectionReference).path;
    } else {
      return _getBaseCollectionPath(query.parentQuery!);
    }
  }

  void register<T>(FakeQueryWithParent query) {
    final path = _getBaseCollectionPath(query);
    if (!_streamCache.containsKey(path)) {
      _streamCache[path] = {};
    }
    _streamCache[path]!.putIfAbsent(
        query, () => StreamController<QuerySnapshot<T>>.broadcast());
  }

  void unregister(FakeQueryWithParent query) {
    final path = _getBaseCollectionPath(query);
    final pathCache = _streamCache[path];
    if (pathCache == null) {
      return;
    }
    final controller = pathCache.remove(query);
    controller!.close();
  }

  StreamController<QuerySnapshot<T>> getStreamController<T>(
      FakeQueryWithParent query) {
    final path = _getBaseCollectionPath(query);
    final pathCache = _streamCache[path];
    // Before calling `getStreamController(query)`, one should have called
    // `register(query)` beforehand, so pathCache should never be null.
    assert(pathCache != null);
    final streamController = pathCache![query]!;
    if (streamController is! StreamController<QuerySnapshot<T>>) {
      throw UnimplementedError();
    }
    return streamController;
  }

  void fireSnapshotUpdate(String path) {
    final exactPathCache = _streamCache[path];
    if (exactPathCache != null) {
      for (final query in exactPathCache.keys) {
        if (exactPathCache[query]!.hasListener) {
          query.get().then(exactPathCache[query]!.add);
        }
      }
    }

    if (path.contains('/')) {
      fireSnapshotUpdate(path.split('/').first);
    }
  }
}
