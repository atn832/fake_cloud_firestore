import 'package:cloud_firestore/cloud_firestore.dart';

class Converter<T extends Object?> {
  Converter(this.fromFirestore, this.toFirestore);

  final FromFirestore<T> fromFirestore;
  final ToFirestore<T> toFirestore;
}
