import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'mock_document_reference.dart';
import 'mock_document_snapshot.dart';
import 'mock_query.dart';
import 'mock_snapshot.dart';
import 'util.dart';

const snapshotsStreamKey = '_snapshots';

class MockCollectionReference extends MockQuery implements CollectionReference {
  final Map<String, dynamic> root;
  final Map<String, dynamic> snapshotStreamControllerRoot;
  String currentChildId = '';

  StreamController<QuerySnapshot> get snapshotStreamController {
    if (!snapshotStreamControllerRoot.containsKey(snapshotsStreamKey)) {
      snapshotStreamControllerRoot[snapshotsStreamKey] =
          StreamController<QuerySnapshot>.broadcast();
    }
    return snapshotStreamControllerRoot[snapshotsStreamKey];
  }

  MockCollectionReference(this.root, this.snapshotStreamControllerRoot)
      : super(root.entries
            .map((entry) => MockDocumentSnapshot(entry.key, entry.value))
            .toList());

  @override
  DocumentReference document([String path]) {
    return MockDocumentReference(path, getSubpath(root, path), root,
        getSubpath(snapshotStreamControllerRoot, path));
  }

  @override
  Future<DocumentReference> add(Map<String, dynamic> data) {
    while (currentChildId.isEmpty || root.containsKey(currentChildId)) {
      currentChildId += 'z';
    }
    final keysWithDateTime = data.keys.where((key) => data[key] is DateTime);
    for (final key in keysWithDateTime) {
      data[key] = Timestamp.fromDate(data[key]);
    }
    root[currentChildId] = data;
    fireSnapshotUpdate();
    return Future.value(document(currentChildId));
  }

  @override
  Query where(
    dynamic field, {
    dynamic isEqualTo,
    dynamic isLessThan,
    dynamic isLessThanOrEqualTo,
    dynamic isGreaterThan,
    dynamic isGreaterThanOrEqualTo,
    dynamic arrayContains,
    List<dynamic> arrayContainsAny,
    List<dynamic> whereIn,
    bool isNull,
  }) {
    final matchingDocuments = root.entries
        .where((entry) {
          final document = entry.value;
          if (isEqualTo != null) {
            return document[field] == isEqualTo;
          } else if (isGreaterThan != null) {
            Comparable fieldValue = document[field];
            if (isGreaterThan is DateTime) {
              isGreaterThan = Timestamp.fromDate(isGreaterThan);
            }
            return fieldValue.compareTo(isGreaterThan) > 0;
          } else if (isGreaterThanOrEqualTo != null) {
            Comparable fieldValue = document[field];
            if (isGreaterThanOrEqualTo is DateTime) {
              isGreaterThanOrEqualTo =
                  Timestamp.fromDate(isGreaterThanOrEqualTo);
            }
            return fieldValue.compareTo(isGreaterThanOrEqualTo) >= 0;
          } else if (isLessThan != null) {
            Comparable fieldValue = document[field];
            if (isLessThan is DateTime) {
              isLessThan = Timestamp.fromDate(isLessThan);
            }
            return fieldValue.compareTo(isLessThan) < 0;
          } else if (isLessThanOrEqualTo != null) {
            Comparable fieldValue = document[field];
            if (isLessThanOrEqualTo is DateTime) {
              isLessThanOrEqualTo = Timestamp.fromDate(isLessThanOrEqualTo);
            }
            return fieldValue.compareTo(isLessThanOrEqualTo) <= 0;
          }
          throw "Unsupported";
        })
        .map((entry) => MockDocumentSnapshot(entry.key, entry.value))
        .toList();
    return MockQuery(matchingDocuments);
  }

  @override
  Stream<QuerySnapshot> snapshots({bool includeMetadataChanges = false}) {
    Future(() {
      fireSnapshotUpdate();
    });
    return snapshotStreamController.stream;
  }

  fireSnapshotUpdate() {
    final documents = root.entries
        .map((entry) => MockDocumentSnapshot(entry.key, entry.value))
        .toList();
    snapshotStreamController.add(MockSnapshot(documents));
  }
}
