import 'package:cloud_firestore/cloud_firestore.dart';

// Firestore has the 3 types of batch writes
// https://firebase.google.com/docs/firestore/manage-data/transactions#batched-writes
enum WriteCommand {
  setData,
  updateData,
  delete,
}

class WriteTask {
  WriteCommand command;
  DocumentReference document;
  Map<String, dynamic> data;
  bool merge;
}
