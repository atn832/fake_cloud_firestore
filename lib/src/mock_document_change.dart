import 'package:cloud_firestore/cloud_firestore.dart';

class MockDocumentChange<T extends Object?> implements DocumentChange<T> {
  final DocumentSnapshot<T> _document;
  final DocumentChangeType _type;
  final int _oldIndex;
  final int _newIndex;

  MockDocumentChange(
    this._document,
    this._type, {
    required int oldIndex,
    required int newIndex,
  })  : _oldIndex = oldIndex,
        _newIndex = newIndex;

  @override
  DocumentChangeType get type => _type;

  @override
  int get oldIndex => _oldIndex;

  @override
  int get newIndex => _newIndex;

  @override
  DocumentSnapshot<T> get doc => _document;
}
