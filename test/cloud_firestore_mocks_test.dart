import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';
import 'package:flutter/services.dart';
import 'package:test/test.dart';

import 'document_snapshot_matcher.dart';
import 'query_snapshot_matcher.dart';

const expectedDumpAfterSetData = """{
  "users": {
    "abc": {
      "name": "Bob"
    }
  }
}""";

const uid = 'abc';

void main() {
  group('MockFirestoreInstance.dump', () {
    test('Sets data for a document within a collection', () async {
      final instance = MockFirestoreInstance();
      await instance.collection('users').document(uid).setData({
        'name': 'Bob',
      });
      expect(instance.dump(), equals(expectedDumpAfterSetData));
    });
    test('Add adds data', () async {
      final instance = MockFirestoreInstance();
      final doc1 = await instance.collection('messages').add({
        'content': 'hello!',
        'uid': uid,
      });
      expect(doc1.documentID.length, greaterThanOrEqualTo(20));
      expect(instance.dump(), equals("""{
  "messages": {
    "${doc1.documentID}": {
      "content": "hello!",
      "uid": "abc"
    }
  }
}"""));
      final doc2 = await instance.collection('messages').add({
        'content': 'there!',
        'uid': uid,
      });
      expect(instance.dump(), equals("""{
  "messages": {
    "${doc1.documentID}": {
      "content": "hello!",
      "uid": "abc"
    },
    "${doc2.documentID}": {
      "content": "there!",
      "uid": "abc"
    }
  }
}"""));
    });
  });

  group('adding data through collection reference', () {
    MockFirestoreInstance instance;
    setUp(() {
      instance = MockFirestoreInstance();
    });
    test('data with server timestamp', () async {
      // arrange
      final collectionRef = await instance.collection('users');
      final data = {
        'username': 'johndoe',
        'joined': FieldValue.serverTimestamp(),
      };
      // act
      final docId = await collectionRef.add(data);
      // assert
      final docSnap =
          await instance.collection('users').document(docId.documentID).get();
      expect(docSnap.data['username'], 'johndoe');
      expect(docSnap.data['joined'], isA<Timestamp>());
    });
  });

  test('nested calls to setData work', () async {
    final firestore = MockFirestoreInstance();
    await firestore
        .collection('userProfiles')
        .document('a')
        .collection('relationship')
        .document('1')
        .setData({'label': 'relationship1'});
    await firestore
        .collection('userProfiles')
        .document('a')
        .collection('relationship')
        .document('2')
        .setData({'label': 'relationship2'});
    expect(
        firestore
            .collection('userProfiles')
            .document('a')
            .collection('relationship')
            .snapshots(),
        emits(QuerySnapshotMatcher([
          DocumentSnapshotMatcher('1', {
            'label': 'relationship1',
          }),
          DocumentSnapshotMatcher('2', {
            'label': 'relationship2',
          })
        ])));
  });
  test('Snapshots returns a Stream of Snapshots', () async {
    final instance = MockFirestoreInstance();
    await instance.collection('users').document(uid).setData({
      'name': 'Bob',
    });
    expect(
        instance.collection('users').snapshots(),
        emits(QuerySnapshotMatcher([
          DocumentSnapshotMatcher('abc', {
            'name': 'Bob',
          })
        ])));
  });
  test('Snapshots returns a Stream of Snapshot', () async {
    final instance = MockFirestoreInstance();
    await instance.collection('users').document(uid).setData({
      'name': 'Bob',
    });
    expect(
        instance.collection('users').document(uid).snapshots(),
        emits(DocumentSnapshotMatcher('abc', {
          'name': 'Bob',
        })));
  });
  test('Snapshots sets exists property to false if the document does not exist',
      () async {
    final instance = MockFirestoreInstance();
    await instance.collection('users').document(uid).setData({
      'name': 'Bob',
    });
    instance
        .collection('users')
        .document('doesnotexist')
        .snapshots()
        .listen(expectAsync1((document) {
      expect(document.exists, equals(false));
    }));
  });

  test('Snapshots sets exists property to true if the document does  exist',
      () async {
    final instance = MockFirestoreInstance();
    await instance.collection('users').document(uid).setData({
      'name': 'Bob',
    });
    instance
        .collection('users')
        .document(uid)
        .snapshots()
        .listen(expectAsync1((document) {
      expect(document.exists, equals(true));
    }));
  });

  test('Document reference path', () async {
    final instance = MockFirestoreInstance();
    final documentReference = instance
        .collection('users')
        .document('aaa')
        .collection('friends')
        .document('bbb')
        .collection('friends-friends')
        .document('ccc');

    expect(documentReference.path, 'users/aaa/friends/bbb/friends-friends/ccc');
    expect(documentReference.parent().path,
        'users/aaa/friends/bbb/friends-friends');
  });

  test('Document and collection parent()', () async {
    final instance = MockFirestoreInstance();
    final documentReference = instance
        .collection('users')
        .document('aaa')
        .collection('friends')
        .document('bbb')
        .collection('friends-friends')
        .document('ccc');

    final friendsFriends = documentReference.parent();
    final bbb = friendsFriends.parent();
    final friends = bbb.parent();
    final bbbSibling = friends.document('bbb-sibling');
    expect(bbbSibling.path, 'users/aaa/friends/bbb-sibling');
  });

  test('firestore field', () async {
    final instance = MockFirestoreInstance();
    final documentReference =
        instance.collection('users').document('aaa').collection('friends');

    expect(documentReference.firestore, instance);
    expect(documentReference.parent().firestore, instance);
  });

  test('Document reference equality', () async {
    final instance = MockFirestoreInstance();
    final documentReference1 = instance
        .collection('users')
        .document('aaa')
        .collection('friends')
        .document('xyz');
    final documentReference2 = instance.document('users/aaa/friends/xyz');

    expect(documentReference1, equals(documentReference2));
  });

  test('Creating document reference should not save the document', () async {
    final instance = MockFirestoreInstance();
    await instance.collection('users').add(<String, dynamic>{'name': 'Foo'});
    final documentReference = instance.collection('users').document(uid);

    var querySnapshot = await instance.collection('users').getDocuments();
    expect(querySnapshot.documents, hasLength(1));

    // Only after setData, the document is available for getDocuments
    await documentReference.setData({'name': 'Bar'});
    querySnapshot = await instance.collection('users').getDocuments();
    expect(querySnapshot.documents, hasLength(2));
  });

  test('Saving documents in subcollection', () async {
    final instance = MockFirestoreInstance();
    // Creates 1st document in "users/abc/friends/<documentId>"
    await instance
        .collection('users')
        .document(uid)
        .collection('friends')
        .add(<String, dynamic>{'name': 'Foo'});

    // The command above does not create a document at "users/abc"
    final intermediateDocument =
        await instance.collection('users').document(uid).get();
    expect(intermediateDocument.exists, false);

    // Gets a reference to an unsaved document.
    // This shouldn't appear in getDocuments
    final documentReference = instance
        .collection('users')
        .document(uid)
        .collection('friends')
        .document('xyz');
    expect(documentReference.path, 'users/$uid/friends/xyz');

    var subcollection =
        instance.collection('users').document(uid).collection('friends');
    var querySnapshot = await subcollection.getDocuments();
    expect(querySnapshot.documents, hasLength(1));

    // Only after setData, the document is available for getDocuments
    await documentReference.setData({'name': 'Bar'});

    // TODO: Remove the line below once MockQuery defers query execution.
    // https://github.com/atn832/cloud_firestore_mocks/issues/31
    subcollection =
        instance.collection('users').document(uid).collection('friends');
    querySnapshot = await subcollection.getDocuments();
    expect(querySnapshot.documents, hasLength(2));
  });

  test('Saving documents through FirestoreInstance.document()', () async {
    final instance = MockFirestoreInstance();

    await instance.document('users/$uid/friends/xyz').setData({
      'name': 'Foo',
      'nested': {
        'k1': 'v1',
      }
    });

    final documentReference = instance
        .collection('users')
        .document(uid)
        .collection('friends')
        .document('xyz');

    final snapshot = await documentReference.get();
    expect(snapshot.data['name'], 'Foo');
    final nested = snapshot.data['nested'] as Map<String, dynamic>;
    expect(nested['k1'], 'v1');
  });

  test('Nonexistent document should have null data', () async {
    final nonExistentId = 'nonExistentId';
    final instance = MockFirestoreInstance();

    final snapshot1 =
        await instance.collection('users').document(nonExistentId).get();
    expect(snapshot1, isNotNull);
    expect(snapshot1.documentID, nonExistentId);
    // data field should be null before the document is saved
    expect(snapshot1.data, isNull);
  });

  test('Snapshots returns a Stream of Snapshots upon each change', () async {
    final instance = MockFirestoreInstance();
    expect(
        instance.collection('users').snapshots(),
        emits(QuerySnapshotMatcher([
          DocumentSnapshotMatcher.onData({
            'name': 'Bob',
          })
        ])));
    await instance.collection('users').add({
      'name': 'Bob',
    });
  });
  test('Stores DateTime and returns Timestamps', () async {
    // As per Firebase's implementation.
    final instance = MockFirestoreInstance();
    final now = DateTime.now();
    // Store a DateTime.
    await instance.collection('messages').add({
      'content': 'hello!',
      'uid': uid,
      'timestamp': now,
    });
    // Expect a Timestamp.
    expect(
        instance.collection('messages').snapshots(),
        emits(QuerySnapshotMatcher([
          DocumentSnapshotMatcher.onData({
            'content': 'hello!',
            'uid': uid,
            'timestamp': Timestamp.fromDate(now),
          })
        ])));
  });

  test('delete', () async {
    final instance = MockFirestoreInstance();
    await instance.collection('users').document(uid).setData({
      'username': 'Bob',
    });
    await instance.collection('users').document(uid).delete();
    final users = await instance.collection('users').getDocuments();
    expect(users.documents.isEmpty, equals(true));
    expect(instance.hasSavedDocument('users/abc'), false);
  });

  group('FieldValue', () {
    test('FieldValue.delete() deletes key values', () async {
      final firestore = MockFirestoreInstance();
      await firestore.document('root/foo').setData({'flower': 'rose'});
      await firestore
          .document('root/foo')
          .setData({'flower': FieldValue.delete()});
      final document = await firestore.document('root/foo').get();
      expect(document.data.isEmpty, equals(true));
    });

    test('FieldValue.serverTimestamp() sets the time', () async {
      final firestore = MockFirestoreInstance();
      await firestore.collection('users').document(uid).setData({
        'created': FieldValue.serverTimestamp(),
      });
      final users = await firestore.collection('users').getDocuments();
      final bob = users.documents.first;
      expect(bob['created'], isNotNull);
      final bobCreated = bob['created'] as Timestamp; // Not DateTime
      final timeDiff = Timestamp.now().millisecondsSinceEpoch -
          bobCreated.millisecondsSinceEpoch;
      // Mock is fast it shouldn't take more than 1000 milliseconds to execute the code above
      expect(timeDiff, lessThan(1000));
    });

    test('FieldValue.increment() increments number', () async {
      final firestore = MockFirestoreInstance();
      // Empty document before updateData
      await firestore.collection('messages').document(uid).setData({
        'int': 0,
        'double': 1.3,
        'previously String': 'foo',
      });
      await firestore.collection('messages').document(uid).updateData({
        'user.counter': 5,
      });

      await firestore.collection('messages').document(uid).updateData({
        'user.counter': FieldValue.increment(2),
        'double': FieldValue.increment(3.3),
        'int': FieldValue.increment(7),
        'previously String': FieldValue.increment(1),
        'previously absent': FieldValue.increment(8),
      });
      final messages = await firestore.collection('messages').getDocuments();
      final message = messages.documents.first;
      expect(message['double'], 1.3 + 3.3);
      expect(message['int'], 7);
      final map = message['user'] as Map<String, dynamic>;
      expect(map['counter'], 5 + 2);
      expect(message['previously String'], 1);
      expect(message['previously absent'], 8);
    });

    test('FieldValue.arrayUnion() adds unique items', () async {
      final firestore = MockFirestoreInstance();
      // Empty document before updateData
      await firestore.collection('messages').document(uid).setData({
        'array': [1, 2, 3],
        'previously String': 'foo',
      });
      await firestore.collection('messages').document(uid).updateData({
        'nested.array': ['a', 'b']
      });

      await firestore.collection('messages').document(uid).updateData({
        'array': FieldValue.arrayUnion([3, 4, 5]),
        'nested.array': FieldValue.arrayUnion(['b', 'c']),
        'previously String': FieldValue.arrayUnion([6, 7]),
        'previously absent': FieldValue.arrayUnion([8, 9]),
      });

      final messages = await firestore.collection('messages').getDocuments();
      final snapshot = messages.documents.first;
      expect(snapshot['array'], [1, 2, 3, 4, 5]);
      final map = snapshot['nested'] as Map<String, dynamic>;
      expect(map['array'], ['a', 'b', 'c']);
      expect(snapshot['previously String'], [6, 7]);
      expect(snapshot['previously absent'], [8, 9]);
    });

    test('FieldValue.arrayRemove() removes items', () async {
      final firestore = MockFirestoreInstance();
      // Empty document before updateData
      await firestore.collection('messages').document(uid).setData({
        'array': [1, 2, 3],
        'previously String': 'foo',
        'untouched': [3],
      });
      await firestore.collection('messages').document(uid).updateData({
        'nested.array': ['a', 'b', 'c']
      });

      await firestore.collection('messages').document(uid).updateData({
        'array': FieldValue.arrayRemove([3, 4]),
        'nested.array': FieldValue.arrayRemove(['b', 'd']),
        'previously String': FieldValue.arrayRemove([8, 9]),
        'previously absent': FieldValue.arrayRemove([8, 9]),
      });

      final messages = await firestore.collection('messages').getDocuments();
      final snapshot = messages.documents.first;
      expect(snapshot['array'], [1, 2]);
      final map = snapshot['nested'] as Map<String, dynamic>;
      expect(map['array'], ['a', 'c']);
      expect(snapshot['untouched'], [3]);
      expect(snapshot['previously String'], []);
      expect(snapshot['previously absent'], []);
    });
  });

  test('setData to nested documents', () async {
    final instance = MockFirestoreInstance();
    await instance.collection('users').document(uid).setData({
      'foo.bar.baz.username': 'SomeName',
      'foo.bar.created': FieldValue.serverTimestamp()
    });

    final snapshot = await instance.collection('users').getDocuments();
    expect(snapshot.documents.length, equals(1));
    final topLevelDocument = snapshot.documents.first;
    expect(topLevelDocument['foo'], isNotNull);
    final secondLevelDocument =
        topLevelDocument['foo'] as Map<dynamic, dynamic>;
    expect(secondLevelDocument['bar'], isNotNull);
    final thirdLevelDocument =
        secondLevelDocument['bar'] as Map<dynamic, dynamic>;
    expect(thirdLevelDocument['baz'], isNotNull);
    final fourthLevelDocument =
        thirdLevelDocument['baz'] as Map<dynamic, dynamic>;
    expect(fourthLevelDocument['username'], 'SomeName');

    final barCreated = thirdLevelDocument['created'] as Timestamp;
    final timeDiff = Timestamp.now().millisecondsSinceEpoch -
        barCreated.millisecondsSinceEpoch;
    // Mock is fast it shouldn't take more than 1000 milliseconds to execute the code above
    expect(timeDiff, lessThan(1000));
  });

  test('updateData to nested documents', () async {
    final instance = MockFirestoreInstance();

    // This field should not be affected by updateData
    await instance.collection('users').document(uid).setData({
      'foo.bar.baz.username': 'SomeName',
    });
    await instance.collection('users').document(uid).updateData({
      'foo.bar.BAZ.username': 'AnotherName',
    });

    // The updateData should not affect the existing key
    final snapshot = await instance.collection('users').getDocuments();
    expect(snapshot.documents.length, equals(1));
    final topLevelDocument = snapshot.documents.first;
    expect(topLevelDocument['foo'], isNotNull);
    final secondLevelDocument =
        topLevelDocument['foo'] as Map<dynamic, dynamic>;
    expect(secondLevelDocument['bar'], isNotNull);
    final thirdLevelDocument =
        secondLevelDocument['bar'] as Map<dynamic, dynamic>;
    expect(thirdLevelDocument['baz'], isNotNull);
    final fourthLevelDocument =
        thirdLevelDocument['baz'] as Map<dynamic, dynamic>;
    expect(fourthLevelDocument['username'], 'SomeName');

    // UpdateData should create the expected object
    final snapshot2 = await instance.collection('users').getDocuments();
    expect(snapshot2.documents.length, equals(1));
    final topLevelDocument2 = snapshot2.documents.first;
    expect(topLevelDocument2['foo'], isNotNull);
    final secondLevelDocument2 =
        topLevelDocument2['foo'] as Map<dynamic, dynamic>;
    expect(secondLevelDocument2['bar'], isNotNull);
    final thirdLevelDocument2 =
        secondLevelDocument2['bar'] as Map<dynamic, dynamic>;
    expect(thirdLevelDocument2['BAZ'], isNotNull);
    final fourthLevelDocument2 =
        thirdLevelDocument2['BAZ'] as Map<dynamic, dynamic>;
    expect(fourthLevelDocument2['username'], 'AnotherName');
  });

  test('updateData to non-object field', () async {
    final instance = MockFirestoreInstance();

    await instance.collection('users').document(uid).setData({
      'foo.name': 'String value to be overwritten',
    });
    // foo.name is a String, but updateData should overwrite it as a Map
    await instance.collection('users').document(uid).updateData({
      'foo.name.firstName': 'Tomo',
    });

    final snapshot = await instance.collection('users').getDocuments();
    expect(snapshot.documents.length, equals(1));
    final topLevelDocument = snapshot.documents.first;
    expect(topLevelDocument['foo'], isNotNull);
    final foo = topLevelDocument['foo'] as Map<dynamic, dynamic>;
    expect(foo['name'], isNotNull);
    // name is not a String
    final fooName = foo['name'] as Map<dynamic, dynamic>;
    final fooNameFirstName = fooName['firstName'] as String;
    expect(fooNameFirstName, 'Tomo');
  });

  test('Copy on save', () async {
    final firestore = MockFirestoreInstance();
    final CollectionReference messages = firestore.collection('messages');

    final array = [
      0,
      1,
      2,
      {
        'nested1': {
          'nested2': [
            {'nested3': 'value3'}
          ]
        }
      }
    ];
    final map = {
      'k1': 'old value 1',
      'nested1': {
        'nested2': {'k2': 'old value 2'}
      }
    };

    // 1: setData
    final DocumentReference document1 = messages.document();
    await document1.setData(<String, dynamic>{
      'array': array,
      'map': map,
    });

    // 2: addData
    final document2 = await messages.add({
      'array': array,
      'map': map,
    });

    // 3: updateData
    final DocumentReference document3 = messages.document();
    await document3.setData({});
    await document3.updateData({
      'array': array,
      'map': map,
    });

    // The following modifications have no effect the data in Firestore
    array.add(3);
    final innerArray = ((array[3] as Map)['nested1'] as Map)['nested2'] as List;
    (innerArray[0] as Map)['nested3'] = 'unexpected value';
    map['k1'] = 'unexpected value';

    final result1 = await document1.get();
    final result2 = await document2.get();
    final result3 = await document3.get();

    await document1.delete();
    await document2.delete();
    await document3.delete();

    final reasons = ['setData', 'add', 'updateData'];
    final results = [result1, result2, result3];
    for (var i = 0; i < results.length; ++i) {
      final result = results[i];
      final expected = [
        0,
        1,
        2,
        {
          'nested1': {
            'nested2': [
              {'nested3': 'value3'}
            ]
          }
        }
      ];
      expect(result.data['array'], expected,
          reason: 'Array modification should not affect ${reasons[i]}');

      final map1 = result.data['map'] as Map<String, dynamic>;
      expect(map1['k1'], 'old value 1',
          reason: 'Map modification should not affect ${reasons[i]}');
      final map2 = map1['nested1'] as Map<String, dynamic>;
      final map3 = map2['nested2'] as Map<String, dynamic>;
      expect(map3['k2'], 'old value 2',
          reason: 'Nested map modification should not affect ${reasons[i]}');
    }
  });

  test('auto generate ID', () async {
    final firestore = MockFirestoreInstance();
    final reference1 = firestore.collection('users').document();
    final document1Id = reference1.documentID;
    final reference2 = firestore.collection('users').document();
    expect(document1Id, isNot(reference2.documentID));

    await reference1.setData({
      'someField': 'someValue',
    });
    final snapshot1 = await reference1.get();
    expect(snapshot1.exists, true);
    // reference2 is not saved
    final snapshot2 = await reference2.get();
    expect(snapshot2.exists, false);

    final snapshot =
        await firestore.collection('users').document(document1Id).get();
    expect(snapshot['someField'], 'someValue');

    QuerySnapshot querySnapshot =
        await firestore.collection('users').getDocuments();
    expect(querySnapshot.documents, hasLength(1));
    expect(querySnapshot.documents.first['someField'], 'someValue');
  });

  test('Snapshot before saving data', () async {
    final firestore = MockFirestoreInstance();
    // These documents are not saved
    final nonExistentId = 'salkdjfaarecikvdiko0';
    final snapshot1 =
        await firestore.collection('users').document(nonExistentId).get();
    expect(snapshot1, isNotNull);
    expect(snapshot1.documentID, nonExistentId);
    expect(snapshot1.data, isNull);
    expect(snapshot1.exists, false);

    final snapshot2 = await firestore.collection('users').document().get();
    expect(snapshot2, isNotNull);
    expect(snapshot2.documentID.length, greaterThanOrEqualTo(20));
    expect(snapshot2.exists, false);
  });

  test('Snapshot should remain after updating data', () async {
    final firestore = MockFirestoreInstance();
    // These documents are not saved
    final reference = firestore.collection('users').document('foo');
    await reference.setData(<String, dynamic>{'name': 'old'});
    await reference.updateData(<String, dynamic>{
      'nested.data.message': 'old nested data',
    });

    final snapshot = await reference.get();

    await reference.setData(<String, dynamic>{'name': 'new'});
    await reference.updateData(<String, dynamic>{
      'nested.data.message': 'new nested data',
    });

    // At the time the snapshot was created, the value was 'old'
    expect(snapshot.data['name'], 'old');
    final nested = snapshot.data['nested'] as Map<String, dynamic>;
    final nestedData = nested['data'] as Map<String, dynamic>;
    expect(nestedData['message'], 'old nested data');
  });

  test('Batch setData', () async {
    final firestore = MockFirestoreInstance();
    final foo = firestore.collection('users').document('foo');
    final bar = firestore.collection('users').document('bar');

    final batch = firestore.batch();
    batch.setData(foo, <String, dynamic>{'name.firstName': 'Foo'});
    batch.setData(bar, <String, dynamic>{'name.firstName': 'Bar'});
    await batch.commit();

    final docs = await firestore.collection('users').getDocuments();
    expect(docs.documents, hasLength(2));

    final firstNames = docs.documents.map((user) {
      final nameMap = user['name'] as Map<String, dynamic>;
      return nameMap['firstName'];
    });
    expect(firstNames, containsAll(['Foo', 'Bar']));
  });

  test('Batch updateData', () async {
    final firestore = MockFirestoreInstance();
    final foo = firestore.collection('users').document('foo');
    await foo.setData(<String, dynamic>{'name.firstName': 'OldValue Foo'});
    final bar = firestore.collection('users').document('bar');
    await foo.setData(<String, dynamic>{'name.firstName': 'OldValue Bar'});

    final batch = firestore.batch();
    batch.updateData(foo, <String, dynamic>{'name.firstName': 'Foo'});
    batch.updateData(bar, <String, dynamic>{'name.firstName': 'Bar'});
    await batch.commit();

    final docs = await firestore.collection('users').getDocuments();
    expect(docs.documents, hasLength(2));

    final firstNames = docs.documents.map((user) {
      final nameMap = user['name'] as Map<String, dynamic>;
      return nameMap['firstName'];
    });
    expect(firstNames, containsAll(['Foo', 'Bar']));
  });

  test('Batch delete', () async {
    final firestore = MockFirestoreInstance();
    final foo = firestore.collection('users').document('foo');
    await foo.setData(<String, dynamic>{'name.firstName': 'Foo'});
    final bar = firestore.collection('users').document('bar');
    await foo.setData(<String, dynamic>{'name.firstName': 'Bar'});

    await firestore
        .collection('users')
        .document()
        .setData(<String, dynamic>{'name.firstName': 'Survivor'});

    final batch = firestore.batch();
    batch.delete(foo);
    batch.delete(bar);
    await batch.commit();

    final docs = await firestore.collection('users').getDocuments();
    expect(docs.documents, hasLength(1));
    final savedFoo = docs.documents.first;
    final nameMap = savedFoo['name'] as Map<String, dynamic>;
    expect(nameMap['firstName'], 'Survivor');
  });

  test('MockFirestoreInstance.document with a valid path', () async {
    final firestore = MockFirestoreInstance();
    final documentReference = firestore.document('users/1234');
    expect(documentReference, isNotNull);
  });

  test('MockFirestoreInstance.document with an invalid path', () async {
    final firestore = MockFirestoreInstance();

    // This should fail because users (1 segments) and users/1234/friends (3 segments)
    // are a reference to a subcollection, not a document.
    // In real Firestore, the behavior of this error depends on the platforms;
    // in iOS, it's NSInternalInconsistencyException that would terminate
    // the app. This library imitates it with assert().
    // https://github.com/atn832/cloud_firestore_mocks/issues/30
    expect(() => firestore.document('users'), throwsA(isA<AssertionError>()));

    // subcollection
    expect(() => firestore.document('users/1234/friends'),
        throwsA(isA<AssertionError>()));
  });

  test('MockFirestoreInstance.collection with an invalid path', () async {
    final firestore = MockFirestoreInstance();

    // This should fail because users/1234 (2 segments) is a reference to a
    // document, not a collection.
    expect(() => firestore.collection('users/1234'),
        throwsA(isA<AssertionError>()));

    expect(() => firestore.collection('users/1234/friends/567'),
        throwsA(isA<AssertionError>()));
  });

  test('Transaction set, update, and delete', () async {
    final firestore = MockFirestoreInstance();
    final foo = firestore.collection('messages').document('foo');
    final bar = firestore.collection('messages').document('bar');
    final baz = firestore.collection('messages').document('baz');
    await foo.setData(<String, dynamic>{'name': 'Foo'});
    await bar.setData(<String, dynamic>{'name': 'Bar'});
    await baz.setData(<String, dynamic>{'name': 'Baz'});

    final result = await firestore.runTransaction((Transaction tx) async {
      final snapshot = await tx.get(foo);

      await tx.set(foo, <String, dynamic>{
        'name': snapshot.data['name'] + 'o',
      });
      await tx.update(bar, <String, dynamic>{
        'nested.field': 123,
      });
      await tx.delete(baz);
      return <String, dynamic>{'k': 'v'};
    });
    expect(result['k'], 'v');

    final updatedSnapshotFoo = await foo.get();
    expect(updatedSnapshotFoo.data['name'], 'Fooo');

    final updatedSnapshotBar = await bar.get();
    final nestedDocument =
        updatedSnapshotBar.data['nested'] as Map<String, dynamic>;
    expect(nestedDocument['field'], 123);

    final deletedSnapshotBaz = await baz.get();
    expect(deletedSnapshotBaz.exists, false);
  });

  test('Transaction: read must come before writes', () async {
    final firestore = MockFirestoreInstance();
    final foo = firestore.collection('messages').document('foo');
    final bar = firestore.collection('messages').document('bar');
    await foo.setData(<String, dynamic>{'name': 'Foo'});
    await bar.setData(<String, dynamic>{'name': 'Bar'});

    Future<dynamic> erroneousTransactionUsage() async {
      await firestore.runTransaction((Transaction tx) async {
        final snapshotFoo = await tx.get(foo);

        await tx.set(foo, <String, dynamic>{
          'name': snapshotFoo.data['name'] + 'o',
        });
        // get cannot come after set
        await tx.get(bar);
      });
    }

    expect(erroneousTransactionUsage, throwsA(isA<PlatformException>()));
  });

  test('Document snapshot data returns a new instance', () async {
    final instance = MockFirestoreInstance();
    await instance.collection('users').document(uid).setData({
      'name': 'Eve',
      'friends': ['Alice', 'Bob'],
    });

    final eve = await instance.collection('users').document(uid).get();
    eve.data['name'] = 'John';
    eve.data['friends'][0] = 'Superman';

    expect(eve.data['name'], isNot('John')); // nothing changed
    expect(eve.data['friends'], equals(['Alice', 'Bob'])); // nothing changed
  });
}
