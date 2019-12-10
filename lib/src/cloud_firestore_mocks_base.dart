import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';

import 'mock_collection_reference.dart';
import 'mock_document_reference.dart';
import 'mock_write_batch.dart';
import 'util.dart';

class MockFirestoreInstance extends Mock implements Firestore {
  Map<String, dynamic> _root = Map();
  Map<String, dynamic> _snapshotStreamControllerRoot = Map();
  
  @override
  CollectionReference collection(String path) {
    return MockCollectionReference(getSubpath(_root, path), getSubpath(_snapshotStreamControllerRoot, path));
  }

  @override
  DocumentReference document(String path) {
    return MockDocumentReference(path, getSubpath(_root, path), _root, getSubpath(_snapshotStreamControllerRoot, path));
  }

  WriteBatch batch() {
    return MockWriteBatch();
  }

  String dump() {
    JsonEncoder encoder = JsonEncoder.withIndent('  ', myEncode);
    final jsonText = encoder.convert(_root);
    return jsonText;
  }
}
