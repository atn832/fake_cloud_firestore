import 'package:cloud_firestore/cloud_firestore.dart';

class WriteTask {
  DocumentReference document;
  Map<String, dynamic> data;
  bool merge;
}
