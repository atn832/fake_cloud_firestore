import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';

import 'write_task.dart';

class MockWriteBatch extends Mock implements WriteBatch {
  List<WriteTask> tasks = [];

  @override
  void set(DocumentReference document, Map<String, dynamic> data,
      [SetOptions? setOptions]) {
    tasks.add(WriteTask()
      ..command = WriteCommand.setData
      ..document = document
      ..data = data
      ..merge = setOptions?.merge);
  }

  @override
  void update(DocumentReference document, Map<String, dynamic> data) {
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
      switch (task.command!) {
        case WriteCommand.setData:
          if (task.merge != null) {
            task.document!.set(task.data!, SetOptions(merge: task.merge));
          } else {
            task.document!.set(task.data!);
          }
          break;
        case WriteCommand.updateData:
          task.document!.update(task.data!);
          break;
        case WriteCommand.delete:
          task.document!.delete();
          break;
      }
    }
    tasks.clear();
    return Future.value();
  }
}
