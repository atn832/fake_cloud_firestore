import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';

import 'mock_snapshot.dart';
import 'util.dart';

class MockQuery extends Mock implements Query {
  List<DocumentSnapshot> documents;

  MockQuery(this.documents);

  @override
  Future<QuerySnapshot> getDocuments({Source source = Source.serverAndCache}) {
    return Future.value(MockSnapshot(documents));
  }

  @override
  Stream<QuerySnapshot> snapshots({bool includeMetadataChanges = false}) {
    return Stream.fromIterable([MockSnapshot(documents)]);
  }

  Query orderBy(dynamic field, {bool descending = false}) {
    final sortedList = List.of(documents);
    sortedList.sort((d1, d2) {
      final value1 = d1.data[field] as Comparable;
      final value2 = d2.data[field];
      final compare = value1.compareTo(value2);
      return descending ? -compare : compare;
    });
    return MockQuery(sortedList);
  }

  Query limit(int length) {
    return MockQuery(documents.sublist(0, min(documents.length, length)));
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
    final matchingDocuments = this.documents.where((document) {
      Comparable value = document[field];
      return valueMatchesQuery(value,
          isEqualTo: isEqualTo,
          isLessThan: isLessThan,
          isLessThanOrEqualTo: isLessThanOrEqualTo,
          isGreaterThan: isGreaterThan,
          isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
          arrayContains: arrayContains,
          arrayContainsAny: arrayContainsAny,
          whereIn: whereIn,
          isNull: isNull);
    }).toList();
    return MockQuery(matchingDocuments);
  }
}
