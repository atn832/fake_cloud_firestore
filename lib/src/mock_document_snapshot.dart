import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';

class MockDocumentSnapshot extends Mock implements DocumentSnapshot {
  final String _documentId;
  final Map<String, dynamic> _document;

  MockDocumentSnapshot(this._documentId, this._document);

  @override
  String get documentID => _documentId;

  @override
  dynamic operator [](String key) {
    return _document[key];
  }

  @override
  Map<String, dynamic> get data => _document;
}
