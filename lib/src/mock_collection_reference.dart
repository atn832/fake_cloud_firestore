import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';

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

  final CollectionReferencePlatform _delegate = null;

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
