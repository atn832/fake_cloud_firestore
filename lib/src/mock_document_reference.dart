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
      final documentToUpdate = _findNestedDocumentToUpdate(key);
      if (documentToUpdate != root) {
        key = key.split('.').last;
      }
      if (value is FieldValue) {
        final fieldValuePlatform = FieldValuePlatform.getDelegate(value) as MockFieldValuePlatform;
        switch (fieldValuePlatform.value) {
          case MockFieldValue.delete:
            documentToUpdate.remove(key);
            break;
          default:
            throw Exception('Not implemented');
        }
      } else if (value is DateTime) {
        documentToUpdate[key] = Timestamp.fromDate(value);
      } else {
        documentToUpdate[key] = value;
      }
    });
    return Future.value(null);
  }

  Map<String, dynamic> _findNestedDocumentToUpdate(String keyWithPeriods) {
    final keyElements = keyWithPeriods.split('.');
    if (keyElements.length == 1) {
      return root;
    }

    Map<String, dynamic> document = root;
    
    // For N elements, iterate until N-1 element.
    // For example, key: "foo.bar.baz", this method return the document pointed by
    // 'foo.bar'. The document will be updated by the caller to have key 'baz'
    final keysToIterate = keyElements.sublist(0, keyElements.length -1 );
    for (String key in keysToIterate) {
      if (!document.containsKey(key)) {
        document[key] = <String, dynamic>{};
        document = document[key];
      } else {
        document = document[key] as Map<String, dynamic>;
      }
    }
    return document;
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
