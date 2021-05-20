import 'package:cloud_firestore/cloud_firestore.dart';

// ignore: subtype_of_sealed_class
abstract class QueryWithParent<T extends Object?> implements Query<T> {
  /// The parent is not typed, because one query could be converted, while the
  /// parent is raw.
  QueryWithParent? get parentQuery;
}
