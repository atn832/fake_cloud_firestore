import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';

import 'write_task.dart';

class MockWriteBatch extends Mock implements WriteBatch {
  List<WriteTask> tasks = [];

  @override
  void setData(DocumentReference document, Map<String, dynamic> data,
      {bool merge = false}) {
    tasks.add(WriteTask()
      ..document = document
      ..data = data
      ..merge = merge);
  }

  @override
  Future<void> commit() {
    for (final task in tasks) {
      task.document.setData(task.data, merge: task.merge);
    }
    tasks.clear();
    return Future.value();
  }
}
