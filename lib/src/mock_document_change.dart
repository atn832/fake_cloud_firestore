import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';

class MockDocumentChange extends Mock implements DocumentChange {
  final DocumentSnapshot _document;

  MockDocumentChange(this._document);

  @override
  DocumentChangeType get type => DocumentChangeType.added;

  @override
  DocumentSnapshot get document => _document;
}
