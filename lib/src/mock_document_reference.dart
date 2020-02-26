import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:mockito/mockito.dart';

import 'mock_collection_reference.dart';
import 'mock_document_snapshot.dart';
import 'mock_field_value_platform.dart';
import 'util.dart';

class MockDocumentReference extends Mock implements DocumentReference {
  final String _documentId;
  final Map<String, dynamic> root;
  final Map<String, dynamic> rootParent;
  final Map<String, dynamic> snapshotStreamControllerRoot;

  MockDocumentReference(this._documentId, this.root, this.rootParent,
      this.snapshotStreamControllerRoot);

  final DocumentReferencePlatform _delegate = null;

  @override
  String get documentID => _documentId;

  @override
  CollectionReference collection(String collectionPath) {
    return MockCollectionReference(getSubpath(root, collectionPath),
        getSubpath(snapshotStreamControllerRoot, collectionPath));
  }

  @override
  Future<void> updateData(Map<String, dynamic> data) {
    data.forEach((key, value) {
      if (value is FieldValue) {
        final valueDelegate = FieldValuePlatform.getDelegate(value);
        final fieldValuePlatform = valueDelegate as MockFieldValuePlatform;
        switch (fieldValuePlatform.value) {
          case MockFieldValue.delete:
            root.remove(key);
            break;
          case MockFieldValue.serverTimestamp:
            // In real Firestore, it's server-side timestamp,
            // but mock tests don't have a server.
            root[key] = Timestamp.now();
            break;
          default:
            throw Exception('Not implemented');
        }
      } else if (value is DateTime) {
        root[key] = Timestamp.fromDate(value);
      } else {
        root[key] = value;
      }
    });
    return Future.value(null);
  }

  @override
  Future<void> setData(Map<String, dynamic> data, {bool merge = false}) {
    if (!merge) {
      root.clear();
    }
    return updateData(data);
  }

  @override
  Future<DocumentSnapshot> get({Source source = Source.serverAndCache}) {
    return Future.value(MockDocumentSnapshot(_documentId, root));
  }

  @override
  Future<void> delete() {
    rootParent.remove(documentID);
    return Future.value();
  }

  @override
  Stream<DocumentSnapshot> snapshots({bool includeMetadataChanges = false}) {
    return Stream.value(MockDocumentSnapshot(_documentId, root));
  }
}
