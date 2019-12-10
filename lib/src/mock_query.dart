import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';

import 'mock_snapshot.dart';

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
      final value1 =  d1.data[field] as Comparable;
      final value2 =  d2.data[field];
      final compare = value1.compareTo(value2);
      return descending ? -compare : compare;
    });
    return MockQuery(sortedList);
  }

  Query limit(int length) {
    return MockQuery(documents.sublist(0, min(documents.length, length)));
  }
}
