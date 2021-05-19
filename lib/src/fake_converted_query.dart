// ignore: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';

import 'converter.dart';
import 'mock_query_snapshot.dart';

// ignore: subtype_of_sealed_class
/// A converted query. It should always be the last query in the chain, so we
/// don't need to implement where, startAt, ..., withConverter.
class FakeConvertedQuery<T extends Object?> implements Query<T> {
  final Query<Map<String, dynamic>> _nonConvertedParentQuery;
  final Converter<T> _converter;

  FakeConvertedQuery(this._nonConvertedParentQuery, this._converter);

  @override
  Future<QuerySnapshot<T>> get([GetOptions? options]) async {
    // Converted query. Its parent contains Map<String, dynamic>.
    final docs = (await _nonConvertedParentQuery.get()).docs;
    final convertedSnapshots = docs
        .map((d) => d.reference
            .withConverter<T>(
                fromFirestore: _converter.fromFirestore,
                toFirestore: _converter.toFirestore)
            .get())
        .toList();
    return MockQuerySnapshot(await Future.wait(convertedSnapshots), _converter);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
