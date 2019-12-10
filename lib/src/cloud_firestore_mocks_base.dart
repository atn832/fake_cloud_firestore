import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';

import 'mock_collection_reference.dart';
import 'mock_document_reference.dart';
import 'mock_write_batch.dart';
import 'util.dart';

class MockFirestoreInstance extends Mock implements Firestore {
  Map<String, dynamic> root = Map();
  Map<String, dynamic> snapshotStreamControllerRoot = Map();
  

  @override
  CollectionReference collection(String path) {
    return MockCollectionReference(getSubpath(root, path), getSubpath(snapshotStreamControllerRoot, path));
  }

  @override
  DocumentReference document(String path) {
    return MockDocumentReference(path, getSubpath(root, path), root, getSubpath(snapshotStreamControllerRoot, path));
  }

  WriteBatch batch() {
    return MockWriteBatch();
  }

  String dump() {
    JsonEncoder encoder = JsonEncoder.withIndent('  ', myEncode);
    final jsonText = encoder.convert(root);
    return jsonText;
  }
}
