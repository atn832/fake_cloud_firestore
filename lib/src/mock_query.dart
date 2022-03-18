import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:quiver/core.dart';

import 'converter.dart';
import 'fake_converted_query.dart';
import 'fake_query_with_parent.dart';
import 'mock_query_platform.dart';
import 'mock_query_snapshot.dart';

typedef _QueryOperation<T extends Object?> = List<DocumentSnapshot<T>> Function(
    List<DocumentSnapshot<T>> input);

// ignore: subtype_of_sealed_class
class MockQuery<T extends Object?> extends FakeQueryWithParent<T> {
  /// Previous query in a Firestore query chain. Null if this instance is a
  /// collection reference. A query chain always starts with a collection
  /// reference, which does not have a previous query.
  final MockQuery<T>? _parentQuery;

  /// Operation to perform in this query, such as "where", "limit", and
  /// "orderBy". Null if this is a collection reference.
  final _QueryOperation<T>? _operation;

  MockQuery(this._parentQuery, this._operation)
      : parameters = _parentQuery?.parameters ?? {};

  @override
  final Map<String, dynamic> parameters;

  // ignore: unused_field
  final QueryPlatform _delegate = MockQueryPlatform();

  @override
  int get hashCode => hash3(_parentQuery, _operation, _delegate);

  @override
  Future<QuerySnapshot<T>> get([GetOptions? options]) async {
    // Collection references: parent query is null.
    // Regular queries: _parentQuery and _operation are not null.
    assert(_parentQuery != null && _operation != null);
    final parentQueryResult = await _parentQuery!.get(options);
    final docs = _operation!(parentQueryResult.docs);
    return MockQuerySnapshot<T>(docs);
  }

  @override
  Query<T> startAfterDocument(DocumentSnapshot snapshot) {
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
  Query<T> orderBy(dynamic field, {bool descending = false}) {
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
  Query<T> startAt(List<dynamic> values) => _cursorUtil(
      orderByKeys: parameters['orderedBy'] ?? [],
      values: values,
      f: (docs, index, exactMatch) => docs.sublist(
            max(0, index),
          ));

  @override
  Query<T> endAt(List<dynamic> values) => _cursorUtil(
      orderByKeys: parameters['orderedBy'] ?? [],
      values: values,
      f: (docs, index, exactMatch) => docs.sublist(
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
  Query<T> _cursorUtil({
    required List<dynamic> values,
    required List<dynamic> orderByKeys,
    required List<DocumentSnapshot<T>> Function(
            List<DocumentSnapshot<T>> docs, int index, bool exactMatch)
        f,
  }) {
    return MockQuery<T>(this, (docs) {
      assert(
        orderByKeys.length >= values.length,
        'You can only specify as many start values as there are orderBy filters.',
      );
      if (docs.isEmpty) return docs;

      var res;
      var found = false;
      for (var i = 0; i < values.length; i++) {
        var sublist = docs.sublist(res ?? 0);
        final keyName = orderByKeys[i];
        final searchedValue = values[i];
        var index = 1 +
            sublist.lastIndexWhere((doc) {
              if (doc.data() == null) {
                return false;
              }
              final docValue = doc.get(keyName);
              return docValue.compareTo(searchedValue) == -1;
            });
        found = sublist[index].get(keyName) == searchedValue;
        res = res == null ? index : res + index;
      }

      return f(docs, res ?? -1, found);
    });
  }

  @override
  Query<T> limit(int length) {
    return MockQuery(this, (docs) => docs.sublist(0, min(docs.length, length)));
  }

  @override
  Query<T> limitToLast(int length) {
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
  Query<T> where(dynamic field,
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
    final operation =
        (List<DocumentSnapshot<T>> docs) => docs.where((document) {
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
    return MockQuery<T>(this, operation);
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
      // It might happen if the value is null for example.
      if (value is! Comparable) {
        return false;
      }
      if (isGreaterThan is DateTime) {
        isGreaterThan = Timestamp.fromDate(isGreaterThan);
      }
      return value.compareTo(isGreaterThan) > 0;
    } else if (isGreaterThanOrEqualTo != null) {
      if (value is! Comparable) {
        return false;
      }
      if (isGreaterThanOrEqualTo is DateTime) {
        isGreaterThanOrEqualTo = Timestamp.fromDate(isGreaterThanOrEqualTo);
      }
      return value.compareTo(isGreaterThanOrEqualTo) >= 0;
    } else if (isLessThan != null) {
      if (value is! Comparable) {
        return false;
      }
      if (isLessThan is DateTime) {
        isLessThan = Timestamp.fromDate(isLessThan);
      }
      return value.compareTo(isLessThan) < 0;
    } else if (isLessThanOrEqualTo != null) {
      if (value is! Comparable) {
        return false;
      }
      if (isLessThanOrEqualTo is DateTime) {
        isLessThanOrEqualTo = Timestamp.fromDate(isLessThanOrEqualTo);
      }
      return value.compareTo(isLessThanOrEqualTo) <= 0;
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

  ///Returns all documents up to [snapshot]. If [snapshot] is not found, returns everything
  @override
  Query<T> endAtDocument(DocumentSnapshot snapshot) {
    return MockQuery(this, (docs) {
      final index = docs.indexWhere((doc) {
        return doc.id == snapshot.id;
      });

      return docs.sublist(0, index == -1 ? docs.length : index + 1);
    });
  }

  ///Returns all documents before [values], If [values] are not found returns everything
  @override
  Query<T> endBefore(List values) => _cursorUtil(
        orderByKeys: parameters['orderedBy'] ?? [],
        values: values,
        f: (docs, index, exactMatch) => docs.sublist(
          0,
          index == -1 ? docs.length - 1 : index,
        ),
      );

  @override
  Query<T> endBeforeDocument(DocumentSnapshot snapshot) {
    return MockQuery(this, (docs) {
      final index = docs.indexWhere((doc) {
        return doc.id == snapshot.id;
      });

      if (index == -1) {
        throw PlatformException(
            code: 'Invalid Query',
            message: 'The document specified wasn\'t found');
      }

      return docs.sublist(0, index);
    });
  }

  @override
  Query<T> startAfter(List values) => _cursorUtil(
      orderByKeys: parameters['orderedBy'] ?? [],
      values: values,
      f: (docs, index, exactMatch) {
        return docs.sublist(
          max(0, index + (exactMatch ? 1 : 0)),
        );
      });

  @override
  Query<T> startAtDocument(DocumentSnapshot snapshot) {
    return MockQuery(this, (docs) {
      final index = docs.indexWhere((doc) {
        return doc.id == snapshot.id;
      });

      return docs.sublist(max(0, index));
    });
  }

  @override
  Query<R> withConverter<R>({required fromFirestore, required toFirestore}) {
    if (this is MockQuery<Map<String, dynamic>>) {
      return FakeConvertedQuery<R>(
          this,
          Converter<R>(
            fromFirestore,
            toFirestore,
          ));
    }
    throw StateError('Shouldn\'t withConverter be called only once?');
  }

  @override
  FakeQueryWithParent? get parentQuery => _parentQuery;
}
