import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/src/util.dart';
import 'package:flutter/services.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:quiver/core.dart';

import 'converter.dart';
import 'fake_converted_query.dart';
import 'fake_query_with_parent.dart';
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

  @override
  int get hashCode => hash2(_parentQuery, _operation);

  @override
  Future<QuerySnapshot<T>> get([GetOptions? options]) async {
    // Collection references: parent query is null.
    // Regular queries: _parentQuery and _operation are not null.
    assert(_parentQuery != null && _operation != null);
    maybeThrowException(this, Invocation.method(#get, [options]));
    final parentQueryResult = await _parentQuery!.get(options);
    final docs = _operation!(parentQueryResult.docs);
    return MockQuerySnapshot<T>(docs, options?.source == Source.cache);
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
      final fields = (parameters['orderedBy'] ?? []);
      for (var index = 0; index < fields.length; index++) {
        sortedList.sort((d1, d2) {
          final field = fields[index];
          // no need to sort if previous order by value are different
          final shouldSort = index == 0 ||
              d1.get(fields[index - 1]) == d2.get(fields[index - 1]);
          if (!shouldSort) {
            return 0;
          }

          dynamic value1;
          if (field is String) {
            try {
              value1 = d1.get(field) as Comparable;
            } catch (error) {
              // This catch catches the case when the key/value does not exist
              // and the case when the value is null, and as a result not a
              // Comparable.
              value1 = null;
            }
          } else if (field == FieldPath.documentId) {
            value1 = d1.id;
          }
          dynamic value2;
          if (field is String) {
            try {
              value2 = d2.get(field);
            } catch (error) {
              // This catch catches only the case when the key/value does not
              // exist.
              value2 = null;
            }
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
      }
      return sortedList;
    });
  }

  @override
  Query<T> startAt(Iterable<Object?> values) => _subQueryByKeyValues(
      orderByKeys: parameters['orderedBy'] ?? [],
      values: values,
      includeValue: false,
      executeQuery: (docs, index) => docs.sublist(
            max(0, index + 1),
          ));

  @override
  Query<T> endAt(Iterable<Object?> values) => _subQueryByKeyValues(
      orderByKeys: parameters['orderedBy'] ?? [],
      values: values,
      includeValue: true,
      executeQuery: (docs, index) => docs.sublist(
            0,
            index + 1,
          ));

  /// Generates a subquery after finding the index of the last element that is
  /// less than the given values.
  ///
  /// values is a list of values which the cursor position will be based on.
  /// orderByKeys are the keys to match the values against.
  /// For more information on why you can specify multiple fields, see
  /// https://firebase.google.com/docs/firestore/query-data/query-cursors#set_cursor_based_on_multiple_fields
  ///
  /// For example if there are 3 keys to order by, and we want the latest
  /// element that is strictly less than (value0, value1, value2), the function
  /// determines the index of the last document where
  /// values[0] <= doc.data()?[orderByKeys[0]],
  /// values[1] <= doc.data()?[orderByKeys[1]],
  /// values[2] < doc.data()?[orderByKeys[2]].
  /// Notice that even if we are looking for a strictly smaller element, we
  /// accept equality for all but the last value. Indeed, (Springfield, Florida)
  /// is less than (Springfield, Massachussets), despite having the same city
  /// name.
  ///
  /// For instance, a startAt cursor function would provide a Function (docs, index)
  /// where docs.sublist(index) is returned, whereas the endAt function would provide
  /// an f(docs, index) where docs.sublist(0, index) would be called.
  Query<T> _subQueryByKeyValues({
    required Iterable<Object?> values,
    required List<dynamic> orderByKeys,
    required bool includeValue,
    required List<DocumentSnapshot<T>> Function(
            List<DocumentSnapshot<T>> docs, int index)
        executeQuery,
  }) {
    final valuesInList = values.toList();

    return MockQuery<T>(this, (docs) {
      assert(
        orderByKeys.length >= valuesInList.length,
        'You can only specify as many start values as there are orderBy filters.',
      );
      if (docs.isEmpty) return docs;

      final index = docs.lastIndexWhere((doc) {
        if (doc.data() == null) {
          return false;
        }
        var isDocSmallerThan = true;
        for (var i = 0; i < values.length; i++) {
          final keyName = orderByKeys[i];
          final searchedValue = valuesInList[i];
          final docValue = doc.get(keyName);
          // Force strict inequality only for the latest value. See the function
          // documentation for an example where this is necessary.
          final isThisValueLessThan =
              (includeValue || i + 1 < valuesInList.length)
                  ? docValue.compareTo(searchedValue) <= 0
                  : docValue.compareTo(searchedValue) < 0;
          isDocSmallerThan &= isThisValueLessThan;
        }
        return isDocSmallerThan;
      });
      return executeQuery(docs, index);
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
  Query<T> where(Object field,
      {Object? isEqualTo,
      Object? isNotEqualTo,
      Object? isLessThan,
      Object? isLessThanOrEqualTo,
      Object? isGreaterThan,
      Object? isGreaterThanOrEqualTo,
      Object? arrayContains,
      Iterable<Object?>? arrayContainsAny,
      Iterable<Object?>? whereIn,
      Iterable<Object?>? whereNotIn,
      bool? isNull}) {
    final operation = (List<DocumentSnapshot<T>> docs) =>
        docs.where((document) {
          dynamic value;
          if (field is String || field is FieldPath) {
            // DocumentSnapshot.get can throw StateError
            // if field cannot be found. In query it does not matter,
            // so catch and set value to null.
            try {
              value = document.get(field);
            } on StateError catch (_) {
              value = null;
            }
          } else if (field == FieldPath.documentId) {
            value = document.id;

            // transform any DocumentReference in the query to id.
            isEqualTo = transformValue(isEqualTo, documentReferenceToId);
            isNotEqualTo = transformValue(isNotEqualTo, documentReferenceToId);
            isLessThan = transformValue(isLessThan, documentReferenceToId);
            isLessThanOrEqualTo =
                transformValue(isLessThanOrEqualTo, documentReferenceToId);
            isGreaterThan =
                transformValue(isGreaterThan, documentReferenceToId);
            isGreaterThanOrEqualTo =
                transformValue(isGreaterThanOrEqualTo, documentReferenceToId);
            arrayContains =
                transformValue(arrayContains, documentReferenceToId);
            arrayContainsAny =
                transformValue(arrayContainsAny, documentReferenceToId);
            whereIn = transformValue(whereIn, documentReferenceToId);
            whereNotIn = transformValue(whereNotIn, documentReferenceToId);
            isNull = transformValue(isNull, documentReferenceToId);
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
              whereNotIn: whereNotIn,
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
      Iterable<Object?>? arrayContainsAny,
      Iterable<Object?>? whereIn,
      Iterable<Object?>? whereNotIn,
      bool? isNull}) {
    if (isEqualTo != null) {
      isEqualTo = transformValue(isEqualTo, timestampFromDateTime);
      return value == isEqualTo;
    } else if (isNotEqualTo != null) {
      isNotEqualTo = transformValue(isNotEqualTo, timestampFromDateTime);
      // requires that value is not null AND not equal to the argument
      return value != null && value != isNotEqualTo;
    } else if (isNull != null) {
      final valueIsNull = value == null;
      return isNull ? valueIsNull : !valueIsNull;
    } else if (isGreaterThan != null) {
      // It might happen if the value is null for example.
      if (value is! Comparable) {
        return false;
      }
      isGreaterThan = transformValue(isGreaterThan, timestampFromDateTime);
      return value.compareTo(isGreaterThan) > 0;
    } else if (isGreaterThanOrEqualTo != null) {
      if (value is! Comparable) {
        return false;
      }
      isGreaterThanOrEqualTo =
          transformValue(isGreaterThanOrEqualTo, timestampFromDateTime);
      return value.compareTo(isGreaterThanOrEqualTo) >= 0;
    } else if (isLessThan != null) {
      if (value is! Comparable) {
        return false;
      }
      isLessThan = transformValue(isLessThan, timestampFromDateTime);
      return value.compareTo(isLessThan) < 0;
    } else if (isLessThanOrEqualTo != null) {
      if (value is! Comparable) {
        return false;
      }
      isLessThanOrEqualTo =
          transformValue(isLessThanOrEqualTo, timestampFromDateTime);
      return value.compareTo(isLessThanOrEqualTo) <= 0;
    } else if (arrayContains != null) {
      if (value is Iterable) {
        return value
            .contains(transformValue(arrayContains, timestampFromDateTime));
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
      if (whereNotIn != null) {
        throw FormatException(
          'arrayContainsAny cannot be combined with whereNotIn',
        );
      }
      if (value is Iterable) {
        arrayContainsAny =
            transformValue(arrayContainsAny, timestampFromDateTime) as List;
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
      whereIn = transformValue(whereIn, timestampFromDateTime) as List;
      if (whereIn.contains(value)) {
        return true;
      }
      return false;
    } else if (whereNotIn != null) {
      if (whereNotIn.length > 10) {
        throw ArgumentError(
          'whereNotIn cannot contain more than 10 comparison values',
        );
      }
      if (arrayContainsAny != null) {
        throw FormatException(
          'whereNotIn cannot be combined with arrayContainsAny',
        );
      }
      whereNotIn = transformValue(whereNotIn, timestampFromDateTime) as List;
      if (whereNotIn.contains(value)) {
        return false;
      }
      return true;
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
  Query<T> endBefore(Iterable<Object?> values) => _subQueryByKeyValues(
        orderByKeys: parameters['orderedBy'] ?? [],
        values: values,
        includeValue: false,
        executeQuery: (docs, index) => docs.sublist(
          0,
          index + 1,
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
  Query<T> startAfter(Iterable<Object?> values) => _subQueryByKeyValues(
      orderByKeys: parameters['orderedBy'] ?? [],
      values: values,
      includeValue: true,
      executeQuery: (docs, index) {
        return docs.sublist(
          max(0, index + 1),
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
