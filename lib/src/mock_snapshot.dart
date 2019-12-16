import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';

class MockSnapshot extends Mock implements QuerySnapshot {
  List<DocumentSnapshot> _documents;

  MockSnapshot(this._documents);

  @override
  List<DocumentSnapshot> get documents => _documents;
}
