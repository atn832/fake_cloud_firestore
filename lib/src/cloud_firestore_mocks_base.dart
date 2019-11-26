import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';

class MockFirestoreInstance extends Mock implements Firestore {
  Map<String, dynamic> root = Map();

  @override
  CollectionReference collection(String path) {
    return MockCollectionReference(getSubpath(root, path));
  }

  @override
  DocumentReference document(String path) {
    return MockDocumentReference(path, getSubpath(root, path));
  }

  WriteBatch batch() {
    return MockWriteBatch();
  }

  String dump() {
    JsonEncoder encoder = new JsonEncoder.withIndent('  ', myEncode);
    final jsonText = encoder.convert(root);
    return jsonText;
  }
}

dynamic myEncode(dynamic item) {
  if (item is DateTime) {
    return item.toIso8601String();
  } else if (item is Timestamp) {
    return item.toDate().toIso8601String();
  } else if (item is FieldValue) {
    return item.type.toString();
  }
  return item;
}

dynamic getSubpath(Map<String, dynamic> root, String path) {
  if (root[path] == null) {
    root[path] = Map<String, dynamic>();
  }
  return root[path];
}

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

class WriteTask {
  DocumentReference document;
  Map<String, dynamic> data;
  bool merge;
}

class MockCollectionReference extends MockQuery implements CollectionReference {
  final Map<String, dynamic> root;
  String currentChildId = '';

  MockCollectionReference(this.root) : super(root.entries
        .map((entry) => MockDocumentSnapshot(entry.key, entry.value))
        .toList());

  @override
  DocumentReference document([String path]) {
    return MockDocumentReference(path, getSubpath(root, path));
  }

  @override
  Future<DocumentReference> add(Map<String, dynamic> data) {
    while (currentChildId.isEmpty || root.containsKey(currentChildId)) {
      currentChildId += 'z';
    }
    final keysWithDateTime = data.keys.where((key) => data[key] is DateTime);
    for (final key in keysWithDateTime) {
      data[key] = Timestamp.fromDate(data[key]);
    }
    root[currentChildId] = data;
    return Future.value(document(currentChildId));
  }

  @override
  Query where(
    dynamic field, {
    dynamic isEqualTo,
    dynamic isLessThan,
    dynamic isLessThanOrEqualTo,
    dynamic isGreaterThan,
    dynamic isGreaterThanOrEqualTo,
    dynamic arrayContains,
    bool isNull,
  }) {
    final matchingDocuments = root.entries
        .where((entry) {
          final document = entry.value;
          if (isEqualTo != null) {
            return document[field] == isEqualTo;
          } else if (isGreaterThan != null) {
            Comparable fieldValue = document[field];
            if (isGreaterThan is DateTime) {
              isGreaterThan = Timestamp.fromDate(isGreaterThan);
            }
            return fieldValue.compareTo(isGreaterThan) > 0;
          } else if (isGreaterThanOrEqualTo != null) {
            Comparable fieldValue = document[field];
            if (isGreaterThanOrEqualTo is DateTime) {
              isGreaterThanOrEqualTo = Timestamp.fromDate(isGreaterThanOrEqualTo);
            }
            return fieldValue.compareTo(isGreaterThanOrEqualTo) >= 0;
          } else if (isLessThan != null) {
            Comparable fieldValue = document[field];
            if (isLessThan is DateTime) {
              isLessThan = Timestamp.fromDate(isLessThan);
            }
            return fieldValue.compareTo(isLessThan) < 0;
          } else if (isLessThanOrEqualTo != null) {
            Comparable fieldValue = document[field];
            if (isLessThanOrEqualTo is DateTime) {
              isLessThanOrEqualTo = Timestamp.fromDate(isLessThanOrEqualTo);
            }
            return fieldValue.compareTo(isLessThanOrEqualTo) <= 0;
          }
          throw "Unsupported";
        })
        .map((entry) => MockDocumentSnapshot(entry.key, entry.value))
        .toList();
    return MockQuery(matchingDocuments);
  }

  @override
  Stream<QuerySnapshot> snapshots({bool includeMetadataChanges = false}) {
    final documents = root.entries
        .map((entry) => MockDocumentSnapshot(entry.key, entry.value))
        .toList();
    return Stream.fromIterable([MockSnapshot(documents)]);
  }
}

class MockQuery extends Mock implements Query {
  List<DocumentSnapshot> documents;

  MockQuery(this.documents);

  @override
  Future<QuerySnapshot> getDocuments({Source source = Source.serverAndCache}) {
    return Future.value(MockSnapshot(documents));
  }

  @override
  Stream<QuerySnapshot> snapshots({bool includeMetadataChanges = false}) {
    return Stream.fromIterable([MockSnapshot(documents)]);
  }

  Query orderBy(dynamic field, {bool descending = false}) {
    final sortedList = List.of(documents);
    sortedList.sort((d1, d2) {
      final value1 =  d1.data[field] as Comparable;
      final value2 =  d2.data[field];
      final compare = value1.compareTo(value2);
      return descending ? -compare : compare;
    });
    return MockQuery(sortedList);
  }

  Query limit(int length) {
    return MockQuery(documents.sublist(0, min(documents.length, length)));
  }
}

class MockSnapshot extends Mock implements QuerySnapshot {
  List<DocumentSnapshot> _documents;

  MockSnapshot(this._documents);

  @override
  List<DocumentSnapshot> get documents => _documents;
}

class MockDocumentSnapshot extends Mock implements DocumentSnapshot {
  final String _documentId;
  final Map<String, dynamic> _document;

  MockDocumentSnapshot(this._documentId, this._document);

  @override
  String get documentID => _documentId;

  @override
  dynamic operator [](String key) {
    return _document[key];
  }

  @override
  Map<String, dynamic> get data => _document;
}

class MockDocumentReference extends Mock implements DocumentReference {
  final String _documentId;
  final Map<String, dynamic> root;

  MockDocumentReference(this._documentId, this.root);

  @override
  String get documentID => _documentId;

  @override
  CollectionReference collection(String collectionPath) {
    return MockCollectionReference(getSubpath(root, collectionPath));
  }

  @override
  Future<void> updateData(Map<String, dynamic> data) {
    data.forEach((key, value) {
      if (value is FieldValue) {
        switch (value.type) {
          case FieldValueType.delete:
            root.remove(key);
            break;
          default:
            throw Exception('Not implemented');
        }
      } else if (value is DateTime) {
        root[key] = Timestamp.fromDate(value);
      } else {
        root[key] = value;
      }
    });
    return Future.value(null);
  }

  @override
  Future<void> setData(Map<String, dynamic> data, {bool merge = false}) {
    if (!merge) {
      root.clear();
    }
    return updateData(data);
  }

  @override
  Future<DocumentSnapshot> get({Source source = Source.serverAndCache}) {
    return Future.value(MockDocumentSnapshot(_documentId, root));
  }
}
