import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';

import 'write_task.dart';

class MockWriteBatch extends Mock implements WriteBatch {
  List<WriteTask> tasks = [];

  @override
  void setData(DocumentReference document, Map<String, dynamic> data,
      {bool merge = false}) {
    tasks.add(WriteTask()
      ..command = WriteCommand.setData
      ..document = document
      ..data = data
      ..merge = merge);
  }

  @override
  void updateData(DocumentReference document, Map<String, dynamic> data) {
    tasks.add(WriteTask()
      ..command = WriteCommand.updateData
      ..document = document
      ..data = data);
  }

  @override
  void delete(DocumentReference document) {
    tasks.add(WriteTask()
      ..command = WriteCommand.delete
      ..document = document);
  }

  @override
  Future<void> commit() {
    for (final task in tasks) {
      switch (task.command) {
        case WriteCommand.setData:
          task.document.setData(task.data, merge: task.merge);
          break;
        case WriteCommand.updateData:
          task.document.updateData(task.data);
          break;
        case WriteCommand.delete:
          task.document.delete();
          break;
      }
    }
    tasks.clear();
    return Future.value();
  }
}
