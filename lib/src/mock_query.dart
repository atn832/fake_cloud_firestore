import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:mockito/mockito.dart';

import 'mock_snapshot.dart';

typedef List<DocumentSnapshot> _QueryOperation(List<DocumentSnapshot> input);

class MockQuery extends Mock implements Query {
  /// Previous query in a Firestore query chain. Null if this instance is a
  /// collection reference. A query chain always starts with a collection
  /// reference, which does not have a previous query.
  final Query _parentQuery;

  /// Operation to perform in this query, such as "where", "limit", and
  /// "orderBy". Null if this is a collection reference.
  final _QueryOperation _operation;

  MockQuery([this._parentQuery, this._operation]);

  // ignore: unused_field
  final QueryPlatform _delegate = null;

  @override
  Future<QuerySnapshot> getDocuments(
      {Source source = Source.serverAndCache}) async {
    assert(_parentQuery != null,
        'Parent query must be non-null except collection references');
    assert(_operation != null,
        'Operation must be non-null except collection references');
    final parentQueryResult = await _parentQuery.getDocuments(source: source);
    final documents = _operation(parentQueryResult.documents);
    return MockSnapshot(documents);
  }

  @override
  Stream<QuerySnapshot> snapshots({bool includeMetadataChanges = false}) {
    return Stream.fromFuture(getDocuments());
  }

  @override
  Query startAfterDocument(DocumentSnapshot snapshot) {
    return MockQuery(this, (documents) {
      int index = documents.indexWhere((doc) {
        return doc.documentID == snapshot.documentID;
      });

      if (index == -1) {
        throw PlatformException(
            code: 'Invalid Query',
            message: 'The document specified wasn\'t found');
      }

      return documents.sublist(index + 1);
    });
  }

  @override
  Query orderBy(dynamic field, {bool descending = false}) {
    return MockQuery(this, (documents) {
      final sortedList = List.of(documents);
      sortedList.sort((d1, d2) {
        final value1 = d1.data[field] as Comparable;
        final value2 = d2.data[field];
        final compare = value1.compareTo(value2);
        return descending ? -compare : compare;
      });
      return sortedList;
    });
  }

  @override
  Query limit(int length) {
    return MockQuery(this,
        (documents) => documents.sublist(0, min(documents.length, length)));
  }

  @override
  Query where(dynamic field,
      {dynamic isEqualTo,
      dynamic isLessThan,
      dynamic isLessThanOrEqualTo,
      dynamic isGreaterThan,
      dynamic isGreaterThanOrEqualTo,
      dynamic arrayContains,
      List<dynamic> arrayContainsAny,
      List<dynamic> whereIn,
      bool isNull}) {
    _QueryOperation operation = (documents) => documents
        .where((document) => _valueMatchesQuery(document[field],
            isEqualTo: isEqualTo,
            isLessThan: isLessThan,
            isLessThanOrEqualTo: isLessThanOrEqualTo,
            isGreaterThan: isGreaterThan,
            isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
            arrayContains: arrayContains,
            arrayContainsAny: arrayContainsAny,
            whereIn: whereIn,
            isNull: isNull))
        .toList();
    return MockQuery(this, operation);
  }

  bool _valueMatchesQuery(dynamic value,
      {dynamic isEqualTo,
      dynamic isLessThan,
      dynamic isLessThanOrEqualTo,
      dynamic isGreaterThan,
      dynamic isGreaterThanOrEqualTo,
      dynamic arrayContains,
      List<dynamic> arrayContainsAny,
      List<dynamic> whereIn,
      bool isNull}) {
    if (isEqualTo != null) {
      return value == isEqualTo;
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
    }
    throw "Unsupported";
  }
}
