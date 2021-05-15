import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:quiver/core.dart';

import 'mock_query_platform.dart';
import 'mock_query_snapshot.dart';

typedef _QueryOperation = List<DocumentSnapshot> Function(
    List<DocumentSnapshot> input);

class MockQuery implements Query {
  /// Previous query in a Firestore query chain. Null if this instance is a
  /// collection reference. A query chain always starts with a collection
  /// reference, which does not have a previous query.
  final MockQuery? _parentQuery;

  /// Operation to perform in this query, such as "where", "limit", and
  /// "orderBy". Null if this is a collection reference.
  final _QueryOperation? _operation;

  MockQuery(this._parentQuery, this._operation)
      : parameters = _parentQuery?.parameters ?? {};

  @override
  final Map<String, dynamic> parameters;

  // ignore: unused_field
  final QueryPlatform _delegate = MockQueryPlatform();

  @override
  int get hashCode => hash3(_parentQuery, _operation, _delegate);

  @override
  Future<QuerySnapshot> get([GetOptions? options]) async {
    assert(_parentQuery != null,
        'Parent query must be non-null except collection references');
    assert(_operation != null,
        'Operation must be non-null except collection references');
    final parentQueryResult = await _parentQuery!.get(options);
    final docs = _operation!(parentQueryResult.docs);
    return MockQuerySnapshot(docs);
  }

  final _unorderedDeepEquality = const DeepCollectionEquality.unordered();

  @override
  Stream<QuerySnapshot> snapshots({bool includeMetadataChanges = false}) {
    QuerySnapshotStreamManager().register(this);
    final controller = QuerySnapshotStreamManager().getStreamController(this);
    controller.addStream(Stream.fromFuture(get()));
    return controller.stream.distinct(_snapshotEquals);
  }

  bool _snapshotEquals(snapshot1, snapshot2) {
    if (snapshot1.docs.length != snapshot2.docs.length) {
      return false;
    }

    for (var i = 0; i < snapshot1.docs.length; i++) {
      if (snapshot1.docs[i].id != snapshot2.docs[i].id) {
        return false;
      }

      if (!_unorderedDeepEquality.equals(
          snapshot1.docs[i].data(), snapshot2.docs[i].data())) {
        return false;
      }
    }
    return true;
  }

  @override
  Query startAfterDocument(DocumentSnapshot snapshot) {
    return MockQuery(this, (docs) {
      final index = docs.indexWhere((doc) {
        return doc.id == snapshot.id;
      });

      if (index == -1) {
        throw PlatformException(
            code: 'Invalid Query',
            message: 'The document specified wasn\'t found');
      }

      return docs.sublist(index + 1);
    });
  }

  @override
  Query orderBy(dynamic field, {bool descending = false}) {
    if (parameters['orderedBy'] == null) parameters['orderedBy'] = [];
    parameters['orderedBy'].add(field);
    return MockQuery(this, (docs) {
      final sortedList = List.of(docs);
      sortedList.sort((d1, d2) {
        dynamic value1;
        if (field is String) {
          value1 = d1.get(field) as Comparable;
        } else if (field == FieldPath.documentId) {
          value1 = d1.id;
        }
        dynamic value2;
        if (field is String) {
          value2 = d2.get(field);
        } else if (field == FieldPath.documentId) {
          value2 = d2.id;
        }
        if (value1 == null && value2 == null) {
          return 0;
        }
        // Return null values first.
        if (value1 == null) {
          return -1;
        }
        if (value2 == null) {
          return 1;
        }
        final compare = value1.compareTo(value2);
        return descending ? -compare : compare;
      });
      return sortedList;
    });
  }

  @override
  Query startAt(List<dynamic> values) => _cursorUtil(
      orderByKeys: parameters['orderedBy'] ?? [],
      values: values,
      f: (docs, index) => docs.sublist(
            max(0, index),
          ));

  @override
  Query endAt(List<dynamic> values) => _cursorUtil(
      orderByKeys: parameters['orderedBy'] ?? [],
      values: values,
      f: (docs, index) => docs.sublist(
            0,
            index == -1 ? docs.length : index + 1,
          ));

  /// Utility function to avoid duplicate code for cursor query modifier
  /// function mocks.
  ///
  /// values is a list of values which the cursor position will be based on.
  /// orderByKeys are the keys to match the values against.
  /// For more information on why you can specify multiple fields, see
  /// https://firebase.google.com/docs/firestore/query-data/query-cursors#set_cursor_based_on_multiple_fields
  ///
  /// This function determines the index of a document where
  /// values[0] == doc.data()?[orderByKeys[0]],
  /// values[1] == doc.data()?[orderByKeys[1]],
  /// values[2] == doc.data()?[orderByKeys[2]],
  /// etc..
  ///
  /// For instance, a startAt cursor function would provide a Function (docs, index)
  /// where docs.sublist(index) is returned, whereas the endAt function would provide
  /// an f(docs, index) where docs.sublist(0, index) would be called.
  Query _cursorUtil({
    required List<dynamic> values,
    required List<dynamic> orderByKeys,
    required List<DocumentSnapshot> Function(
            List<DocumentSnapshot> docs, int index)
        f,
  }) {
    return MockQuery(this, (docs) {
      assert(
        orderByKeys.length >= values.length,
        'You can only specify as many start values as there are orderBy filters.',
      );
      if (docs.isEmpty) return docs;

      var res;
      for (var i = 0; i < values.length; i++) {
        var index = docs
            .sublist(res ?? 0)
            .indexWhere((doc) => doc.data()?[orderByKeys[i]] == values[i]);
        if (index == -1) break;
        res = res == null ? index : res + index;
      }

      return f(docs, res ?? -1);
    });
  }

  @override
  Query limit(int length) {
    return MockQuery(this, (docs) => docs.sublist(0, min(docs.length, length)));
  }

  @override
  Query limitToLast(int length) {
    assert(
      parameters['orderedBy'] is List && parameters['orderedBy'].isNotEmpty,
      'You can only use limitToLast if at least one orderBy clause is specified.',
    );
    return MockQuery(
      this,
      (docs) => docs.sublist(max(0, docs.length - length), docs.length),
    );
  }

  @override
  Query where(dynamic field,
      {dynamic isEqualTo,
      dynamic isNotEqualTo,
      dynamic isLessThan,
      dynamic isLessThanOrEqualTo,
      dynamic isGreaterThan,
      dynamic isGreaterThanOrEqualTo,
      dynamic arrayContains,
      List<dynamic>? arrayContainsAny,
      List<dynamic>? whereIn,
      List<dynamic>? whereNotIn,
      bool? isNull}) {
    final operation = (List<DocumentSnapshot> docs) => docs.where((document) {
          dynamic value;
          if (field is String) {
            value = document.get(field);
          } else if (field == FieldPath.documentId) {
            value = document.id;
          }
          return _valueMatchesQuery(value,
              isEqualTo: isEqualTo,
              isNotEqualTo: isNotEqualTo,
              isLessThan: isLessThan,
              isLessThanOrEqualTo: isLessThanOrEqualTo,
              isGreaterThan: isGreaterThan,
              isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
              arrayContains: arrayContains,
              arrayContainsAny: arrayContainsAny,
              whereIn: whereIn,
              isNull: isNull);
        }).toList();
    return MockQuery(this, operation);
  }

  bool _valueMatchesQuery(dynamic value,
      {dynamic isEqualTo,
      dynamic isNotEqualTo,
      dynamic isLessThan,
      dynamic isLessThanOrEqualTo,
      dynamic isGreaterThan,
      dynamic isGreaterThanOrEqualTo,
      dynamic arrayContains,
      List<dynamic>? arrayContainsAny,
      List<dynamic>? whereIn,
      bool? isNull}) {
    if (isEqualTo != null) {
      return value == isEqualTo;
    } else if (isNotEqualTo != null) {
      return value != isNotEqualTo;
    } else if (isNull != null) {
      final valueIsNull = value == null;
      return isNull ? valueIsNull : !valueIsNull;
    } else if (isGreaterThan != null) {
      Comparable fieldValue = value;
      if (isGreaterThan is DateTime) {
        isGreaterThan = Timestamp.fromDate(isGreaterThan);
      }
      return fieldValue.compareTo(isGreaterThan) > 0;
    } else if (isGreaterThanOrEqualTo != null) {
      Comparable fieldValue = value;
      if (isGreaterThanOrEqualTo is DateTime) {
        isGreaterThanOrEqualTo = Timestamp.fromDate(isGreaterThanOrEqualTo);
      }
      return fieldValue.compareTo(isGreaterThanOrEqualTo) >= 0;
    } else if (isLessThan != null) {
      Comparable fieldValue = value;
      if (isLessThan is DateTime) {
        isLessThan = Timestamp.fromDate(isLessThan);
      }
      return fieldValue.compareTo(isLessThan) < 0;
    } else if (isLessThanOrEqualTo != null) {
      Comparable fieldValue = value;
      if (isLessThanOrEqualTo is DateTime) {
        isLessThanOrEqualTo = Timestamp.fromDate(isLessThanOrEqualTo);
      }
      return fieldValue.compareTo(isLessThanOrEqualTo) <= 0;
    } else if (arrayContains != null) {
      if (value is Iterable) {
        return value.contains(arrayContains);
      } else {
        return false;
      }
    } else if (arrayContainsAny != null) {
      if (arrayContainsAny.length > 10) {
        throw ArgumentError(
          'arrayContainsAny cannot contain more than 10 comparison values',
        );
      }
      if (whereIn != null) {
        throw FormatException(
          'arrayContainsAny cannot be combined with whereIn',
        );
      }
      if (value is Iterable) {
        var valueSet = Set.from(value);
        for (var elem in arrayContainsAny) {
          if (valueSet.contains(elem)) {
            return true;
          }
        }
        return false;
      } else {
        return false;
      }
    } else if (whereIn != null) {
      if (whereIn.length > 10) {
        throw ArgumentError(
          'whereIn cannot contain more than 10 comparison values',
        );
      }
      if (arrayContainsAny != null) {
        throw FormatException(
          'whereIn cannot be combined with arrayContainsAny',
        );
      }
      if (whereIn.contains(value)) {
        return true;
      }
      return false;
    }
    throw 'Unsupported';
  }

  @override
  Query endAtDocument(DocumentSnapshot documentSnapshot) {
    // TODO: implement endAtDocument
    throw UnimplementedError();
  }

  @override
  Query endBefore(List values) {
    // TODO: implement endBefore
    throw UnimplementedError();
  }

  @override
  Query endBeforeDocument(DocumentSnapshot documentSnapshot) {
    // TODO: implement endBeforeDocument
    throw UnimplementedError();
  }

  @override
  // TODO: implement firestore
  FirebaseFirestore get firestore => throw UnimplementedError();

  @override
  Query startAfter(List values) {
    // TODO: implement startAfter
    throw UnimplementedError();
  }

  @override
  Query startAtDocument(DocumentSnapshot documentSnapshot) {
    // TODO: implement startAtDocument
    throw UnimplementedError();
  }
}

class QuerySnapshotStreamManager {
  static QuerySnapshotStreamManager? _instance;

  factory QuerySnapshotStreamManager() =>
      _instance ??= QuerySnapshotStreamManager._internal();

  QuerySnapshotStreamManager._internal();
  final Map<String, Map<Query, StreamController<QuerySnapshot>>> _streamCache =
      {};

  void clear() {
    for (final queryToStreamController in _streamCache.values) {
      for (final streamController in queryToStreamController.values) {
        streamController.close();
      }
    }
    _streamCache.clear();
  }

  String _retrieveParentPath(MockQuery query) {
    // In theory retrieveParentPath should stop at the collection reference.
    // So _parentQuery can never be null.
    assert(query._parentQuery != null);
    if (query._parentQuery is CollectionReference) {
      return (query._parentQuery as CollectionReference).path;
    } else {
      return _retrieveParentPath(query._parentQuery!);
    }
  }

  void register(MockQuery query) {
    final path = _retrieveParentPath(query);
    if (_streamCache.containsKey(path)) {
      _streamCache[path]!.putIfAbsent(
          query, () => StreamController<QuerySnapshot>.broadcast());
    } else {
      _streamCache[path] = {query: StreamController<QuerySnapshot>.broadcast()};
    }
  }

  void unregister(MockQuery query) {
    final path = _retrieveParentPath(query);
    final pathCache = _streamCache[path];
    if (pathCache == null) {
      return;
    }
    final controller = pathCache.remove(query);
    controller!.close();
  }

  StreamController<QuerySnapshot> getStreamController(MockQuery query) {
    final path = _retrieveParentPath(query);
    final pathCache = _streamCache[path];
    // Before calling `getStreamController(query)`, one should have called
    // `register(query)` beforehand, so pathCache should never be null.
    assert(pathCache != null);
    return pathCache![query]!;
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
