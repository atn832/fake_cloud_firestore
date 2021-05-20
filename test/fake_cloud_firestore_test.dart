import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:test/test.dart';

import 'document_snapshot_matcher.dart';
import 'query_snapshot_matcher.dart';

const uid = 'abc';

void main() {
  group('dump', () {
    const expectedDumpAfterset = '''{
  "users": {
    "abc": {
      "name": "Bob"
    }
  }
}''';

    test('Sets data for a document within a collection', () async {
      final instance = FakeFirebaseFirestore();
      await instance.collection('users').doc(uid).set({
        'name': 'Bob',
      });
      expect(instance.dump(), equals(expectedDumpAfterset));
    });
    test('Add adds data', () async {
      final instance = FakeFirebaseFirestore();
      final doc1 = await instance.collection('messages').add({
        'content': 'hello!',
        'uid': uid,
      });
      expect(doc1.id.length, greaterThanOrEqualTo(20));
      expect(instance.dump(), equals('''{
  "messages": {
    "${doc1.id}": {
      "content": "hello!",
      "uid": "abc"
    }
  }
}'''));
      final doc2 = await instance.collection('messages').add({
        'content': 'there!',
        'uid': uid,
      });
      expect(instance.dump(), equals('''{
  "messages": {
    "${doc1.id}": {
      "content": "hello!",
      "uid": "abc"
    },
    "${doc2.id}": {
      "content": "there!",
      "uid": "abc"
    }
  }
}'''));
    });
  });

  test('brackets to read a field', () async {
    final instance = FakeFirebaseFirestore();
    final docRef = instance.doc('users/alice');
    await docRef.set({'name': 'Alice'});
    expect((await docRef.get())['name'], equals('Alice'));
  });

  group('adding data through collection reference', () {
    late FakeFirebaseFirestore instance;
    setUp(() {
      instance = FakeFirebaseFirestore();
    });
    test('data with server timestamp', () async {
      // arrange
      final collectionRef = instance.collection('users');
      final data = {
        'username': 'johndoe',
        'joined': FieldValue.serverTimestamp(),
      };
      // act
      final docId = await collectionRef.add(data);
      // assert
      final docSnap = await instance.collection('users').doc(docId.id).get();
      expect(docSnap.get('username'), 'johndoe');
      expect(docSnap.get('joined'), isA<Timestamp>());
    });
  });

  test('nested calls to set work', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('userProfiles')
        .doc('a')
        .collection('relationship')
        .doc('1')
        .set({'label': 'relationship1'});
    await firestore
        .collection('userProfiles')
        .doc('a')
        .collection('relationship')
        .doc('2')
        .set({'label': 'relationship2'});
    expect(
        firestore
            .collection('userProfiles')
            .doc('a')
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
    final instance = FakeFirebaseFirestore();
    await instance.collection('users').doc(uid).set({
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
    final instance = FakeFirebaseFirestore();
    // await instance.collection('users').doc(uid).set({
    //   'name': 'Bob',
    // });
    expect(
        instance.collection('users').doc(uid).snapshots(),
        emitsInOrder([
          DocumentSnapshotMatcher('abc', {
            'name': 'Bob',
          }),
          DocumentSnapshotMatcher('abc', {
            'name': 'Frank',
          }),
        ]));
    await instance.collection('users').doc(uid).set({
      'name': 'Bob',
    });
    await instance.collection('users').doc(uid).update({
      'name': 'Frank',
    });
  });
  test('Snapshots returns a Stream of Snapshot changes', () async {
    final instance = FakeFirebaseFirestore();
    const data = {'name': 'Bob'};
    await instance.collection('users').doc(uid).set(data);
    instance.collection('users').snapshots().listen(expectAsync1((snap) {
      expect(snap.docChanges.length, 1);
      expect(snap.docChanges.first.doc.data(), data);
      expect(snap.docChanges[0].type, DocumentChangeType.added);
      expect(snap.docChanges[0].oldIndex, -1);
      expect(snap.docChanges[0].newIndex, 0);
    }));
  });
  test('Snapshots sets exists property to false if the document does not exist',
      () async {
    final instance = FakeFirebaseFirestore();
    await instance.collection('users').doc(uid).set({
      'name': 'Bob',
    });
    instance
        .collection('users')
        .doc('doesnotexist')
        .snapshots()
        .listen(expectAsync1((document) {
      expect(document.exists, equals(false));
    }));
  });

  test('Snapshots sets exists property to true if the document does  exist',
      () async {
    final instance = FakeFirebaseFirestore();
    await instance.collection('users').doc(uid).set({
      'name': 'Bob',
    });
    instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(expectAsync1((document) {
      expect(document.exists, equals(true));
    }));
  });

  test('Document reference path', () async {
    final instance = FakeFirebaseFirestore();
    final documentReference = instance
        .collection('users')
        .doc('aaa')
        .collection('friends')
        .doc('bbb')
        .collection('friends-friends')
        .doc('ccc');

    expect(documentReference.path, 'users/aaa/friends/bbb/friends-friends/ccc');
    expect(
        documentReference.parent.path, 'users/aaa/friends/bbb/friends-friends');
  });

  test('Document and collection parent', () async {
    final instance = FakeFirebaseFirestore();
    final documentReference = instance
        .collection('users')
        .doc('aaa')
        .collection('friends')
        .doc('bbb')
        .collection('friends-friends')
        .doc('ccc');

    final friendsFriends = documentReference.parent;
    final bbb = friendsFriends.parent;
    expect(bbb, isNotNull);
    final friends = bbb!.parent;
    final bbbSibling = friends.doc('bbb-sibling');
    expect(bbbSibling.path, 'users/aaa/friends/bbb-sibling');
  });

  test('firestore field', () async {
    final instance = FakeFirebaseFirestore();
    final documentReference =
        instance.collection('users').doc('aaa').collection('friends');

    expect(documentReference.firestore, instance);
    final parent = documentReference.parent;
    expect(parent, isNotNull);
    expect(parent!.firestore, instance);
  });

  test('Document reference equality', () async {
    final instance = FakeFirebaseFirestore();
    final documentReference1 = instance
        .collection('users')
        .doc('aaa')
        .collection('friends')
        .doc('xyz');
    final documentReference2 = instance.doc('users/aaa/friends/xyz');

    expect(documentReference1, equals(documentReference2));
  });

  test('Creating document reference should not save the document', () async {
    final instance = FakeFirebaseFirestore();
    await instance.collection('users').add(<String, dynamic>{'name': 'Foo'});
    final documentReference = instance.collection('users').doc(uid);

    var querySnapshot = await instance.collection('users').get();
    expect(querySnapshot.docs, hasLength(1));

    // Only after set, the document is available for get
    await documentReference.set({'name': 'Bar'});
    querySnapshot = await instance.collection('users').get();
    expect(querySnapshot.docs, hasLength(2));
  });

  test('Saving docs in subcollection', () async {
    final instance = FakeFirebaseFirestore();
    // Creates 1st document in "users/abc/friends/<id>"
    await instance
        .collection('users')
        .doc(uid)
        .collection('friends')
        .add(<String, dynamic>{'name': 'Foo'});

    // The command above does not create a document at "users/abc"
    final intermediateDocument =
        await instance.collection('users').doc(uid).get();
    expect(intermediateDocument.exists, false);

    // Gets a reference to an unsaved document.
    // This shouldn't appear in get
    final documentReference =
        instance.collection('users').doc(uid).collection('friends').doc('xyz');
    expect(documentReference.path, 'users/$uid/friends/xyz');

    var subcollection =
        instance.collection('users').doc(uid).collection('friends');
    var querySnapshot = await subcollection.get();
    expect(querySnapshot.docs, hasLength(1));

    // Only after set, the document is available for get
    await documentReference.set({'name': 'Bar'});

    // TODO: Remove the line below once MockQuery defers query execution.
    // https://github.com/atn832/fake_cloud_firestore/issues/31
    subcollection = instance.collection('users').doc(uid).collection('friends');
    querySnapshot = await subcollection.get();
    expect(querySnapshot.docs, hasLength(2));
  });

  test('Saving docs through FirestoreInstance.doc()', () async {
    final instance = FakeFirebaseFirestore();

    await instance.doc('users/$uid/friends/xyz').set({
      'name': 'Foo',
      'nested': {
        'k1': 'v1',
      }
    });

    final documentReference =
        instance.collection('users').doc(uid).collection('friends').doc('xyz');

    final snapshot = await documentReference.get();
    expect(snapshot.get('name'), 'Foo');
    final nested = snapshot.get('nested') as Map<String, dynamic>;
    expect(nested['k1'], 'v1');
  });

  test('Nonexistent document should have null data', () async {
    final nonExistentId = 'nonExistentId';
    final instance = FakeFirebaseFirestore();

    final snapshot1 =
        await instance.collection('users').doc(nonExistentId).get();
    expect(snapshot1, isNotNull);
    expect(snapshot1.id, nonExistentId);
    // data field should be null before the document is saved
    expect(snapshot1.data(), isNull);
  });

  test('Snapshots returns a Stream of Snapshots upon each change', () async {
    final instance = FakeFirebaseFirestore();
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
    final instance = FakeFirebaseFirestore();
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
    final instance = FakeFirebaseFirestore();
    await instance.collection('users').doc(uid).set({
      'username': 'Bob',
    });
    await instance.collection('users').doc(uid).delete();
    final users = await instance.collection('users').get();
    expect(users.docs.isEmpty, equals(true));
    expect(instance.hasSavedDocument('users/abc'), false);
  });

  group('FieldValue', () {
    test('FieldValue.delete() deletes key values', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.doc('root/foo').set({'flower': 'rose'});
      await firestore.doc('root/foo').set({'flower': FieldValue.delete()});
      final document = await firestore.doc('root/foo').get();
      final data = document.data();
      expect(data, isNotNull);
      expect(data!.isEmpty, equals(true));
    });

    test('FieldValue.serverTimestamp() sets the time', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc(uid).set({
        'created': FieldValue.serverTimestamp(),
      });
      final users = await firestore.collection('users').get();
      final bob = users.docs.first;
      expect(bob.get('created'), isNotNull);
      final bobCreated = bob.get('created') as Timestamp; // Not DateTime
      final timeDiff = Timestamp.now().millisecondsSinceEpoch -
          bobCreated.millisecondsSinceEpoch;
      // Mock is fast it shouldn't take more than 1000 milliseconds to execute the code above
      expect(timeDiff, lessThan(1000));
    });

    test('FieldValue.increment() increments number', () async {
      final firestore = FakeFirebaseFirestore();
      // Empty document before update
      await firestore.collection('messages').doc(uid).set({
        'int': 0,
        'double': 1.3,
        'previously String': 'foo',
      });
      await firestore.collection('messages').doc(uid).update({
        'user.counter': 5,
      });

      await firestore.collection('messages').doc(uid).update({
        'user.counter': FieldValue.increment(2),
        'double': FieldValue.increment(3.3),
        'int': FieldValue.increment(7),
        'previously String': FieldValue.increment(1),
        'previously absent': FieldValue.increment(8),
      });
      final messages = await firestore.collection('messages').get();
      final message = messages.docs.first;
      expect(message.get('double'), 1.3 + 3.3);
      expect(message.get('int'), 7);
      final map = message.get('user') as Map<String, dynamic>;
      expect(map['counter'], 5 + 2);
      expect(message.get('previously String'), 1);
      expect(message.get('previously absent'), 8);
    });

    test('FieldValue.arrayUnion() adds unique items', () async {
      final firestore = FakeFirebaseFirestore();
      // Empty document before update
      await firestore.collection('messages').doc(uid).set({
        'array': [1, 2, 3],
        'previously String': 'foo',
      });
      await firestore.collection('messages').doc(uid).update({
        'nested.array': ['a', 'b']
      });

      await firestore.collection('messages').doc(uid).update({
        'array': FieldValue.arrayUnion([3, 4, 5]),
        'nested.array': FieldValue.arrayUnion(['b', 'c']),
        'previously String': FieldValue.arrayUnion([6, 7]),
        'previously absent': FieldValue.arrayUnion([8, 9]),
      });

      final messages = await firestore.collection('messages').get();
      final snapshot = messages.docs.first;
      expect(snapshot.get('array'), [1, 2, 3, 4, 5]);
      final map = snapshot.get('nested') as Map<String, dynamic>;
      expect(map['array'], ['a', 'b', 'c']);
      expect(snapshot.get('previously String'), [6, 7]);
      expect(snapshot.get('previously absent'), [8, 9]);
    });

    test('FieldValue.arrayRemove() removes items', () async {
      final firestore = FakeFirebaseFirestore();
      // Empty document before update
      await firestore.collection('messages').doc(uid).set({
        'array': [1, 2, 3],
        'previously String': 'foo',
        'untouched': [3],
      });
      await firestore.collection('messages').doc(uid).update({
        'nested.array': ['a', 'b', 'c']
      });

      await firestore.collection('messages').doc(uid).update({
        'array': FieldValue.arrayRemove([3, 4]),
        'nested.array': FieldValue.arrayRemove(['b', 'd']),
        'previously String': FieldValue.arrayRemove([8, 9]),
        'previously absent': FieldValue.arrayRemove([8, 9]),
      });

      final messages = await firestore.collection('messages').get();
      final snapshot = messages.docs.first;
      expect(snapshot.get('array'), [1, 2]);
      final map = snapshot.get('nested') as Map<String, dynamic>;
      expect(map['array'], ['a', 'c']);
      expect(snapshot.get('untouched'), [3]);
      expect(snapshot.get('previously String'), []);
      expect(snapshot.get('previously absent'), []);
    });

    test('FieldValue in nested objects', () async {
      final firestore = FakeFirebaseFirestore();
      final docRef = firestore.collection('MyCollection').doc('MyDocument');
      final batch = firestore.batch();

      batch.set(
          docRef,
          {
            'testme': FieldValue.increment(1),
            'updated': FieldValue.serverTimestamp(),
            'Nested': {'testnestedfield': FieldValue.increment(1)}
          },
          SetOptions(merge: true));
      await batch.commit();

      final myDocs = await firestore.collection('MyCollection').get();
      expect(myDocs.docs.length, 1);

      final today = DateTime.now();
      final myDoc = myDocs.docs.first;
      final Timestamp updatedTimestamp = myDoc.get('updated');
      final updated = updatedTimestamp.toDate();
      expect(updated.month, today.month);
      expect(updated.day, today.day);
      expect(updated.year, today.year);
      expect(updated.hour, today.hour);
      expect(myDoc.get('testme'), 1);
      final count = myDoc.get('Nested')['testnestedfield'];
      expect(count, 1);
    });
  });

  test('set to nested docs', () async {
    final instance = FakeFirebaseFirestore();
    await instance.collection('users').doc(uid).set({
      'foo.bar.baz.username': 'SomeName',
      'foo.bar.created': FieldValue.serverTimestamp()
    });

    final snapshot = await instance.collection('users').get();
    expect(snapshot.docs.length, equals(1));
    final topLevelDocument = snapshot.docs.first;
    expect(topLevelDocument.get('foo'), isNotNull);
    final secondLevelDocument =
        topLevelDocument.get('foo') as Map<dynamic, dynamic>;
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

  test('update to nested docs', () async {
    final instance = FakeFirebaseFirestore();

    // This field should not be affected by update
    await instance.collection('users').doc(uid).set({
      'foo.bar.baz.username': 'SomeName',
    });
    await instance.collection('users').doc(uid).update({
      'foo.bar.BAZ.username': 'AnotherName',
    });

    // The update should not affect the existing key
    final snapshot = await instance.collection('users').get();
    expect(snapshot.docs.length, equals(1));
    final topLevelDocument = snapshot.docs.first;
    expect(topLevelDocument.get('foo'), isNotNull);
    final secondLevelDocument =
        topLevelDocument.get('foo') as Map<dynamic, dynamic>;
    expect(secondLevelDocument['bar'], isNotNull);
    final thirdLevelDocument =
        secondLevelDocument['bar'] as Map<dynamic, dynamic>;
    expect(thirdLevelDocument['baz'], isNotNull);
    final fourthLevelDocument =
        thirdLevelDocument['baz'] as Map<dynamic, dynamic>;
    expect(fourthLevelDocument['username'], 'SomeName');

    // update should create the expected object
    final snapshot2 = await instance.collection('users').get();
    expect(snapshot2.docs.length, equals(1));
    final topLevelDocument2 = snapshot2.docs.first;
    expect(topLevelDocument2.get('foo'), isNotNull);
    final secondLevelDocument2 =
        topLevelDocument2.get('foo') as Map<dynamic, dynamic>;
    expect(secondLevelDocument2['bar'], isNotNull);
    final thirdLevelDocument2 =
        secondLevelDocument2['bar'] as Map<dynamic, dynamic>;
    expect(thirdLevelDocument2['BAZ'], isNotNull);
    final fourthLevelDocument2 =
        thirdLevelDocument2['BAZ'] as Map<dynamic, dynamic>;
    expect(fourthLevelDocument2['username'], 'AnotherName');
  });

  test('update to non-object field', () async {
    final instance = FakeFirebaseFirestore();

    await instance.collection('users').doc(uid).set({
      'foo.name': 'String value to be overwritten',
    });
    // foo.name is a String, but update should overwrite it as a Map
    await instance.collection('users').doc(uid).update({
      'foo.name.firstName': 'Tomo',
    });

    final snapshot = await instance.collection('users').get();
    expect(snapshot.docs.length, equals(1));
    final topLevelDocument = snapshot.docs.first;
    expect(topLevelDocument.get('foo'), isNotNull);
    final foo = topLevelDocument.get('foo') as Map<dynamic, dynamic>;
    expect(foo['name'], isNotNull);
    // name is not a String
    final fooName = foo['name'] as Map<dynamic, dynamic>;
    final fooNameFirstName = fooName['firstName'] as String;
    expect(fooNameFirstName, 'Tomo');
  });

  test('Copy on save', () async {
    final firestore = FakeFirebaseFirestore();
    final messages = firestore.collection('messages');

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

    // 1: set
    final document1 = messages.doc();
    await document1.set(<String, dynamic>{
      'array': array,
      'map': map,
    });

    // 2: addData
    final document2 = await messages.add({
      'array': array,
      'map': map,
    });

    // 3: update
    final document3 = messages.doc();
    await document3.set({});
    await document3.update({
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

    final reasons = ['set', 'add', 'update'];
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
      expect(result.get('array'), expected,
          reason: 'Array modification should not affect ${reasons[i]}');

      final map1 = result.get('map') as Map<String, dynamic>;
      expect(map1['k1'], 'old value 1',
          reason: 'Map modification should not affect ${reasons[i]}');
      final map2 = map1['nested1'] as Map<String, dynamic>;
      final map3 = map2['nested2'] as Map<String, dynamic>;
      expect(map3['k2'], 'old value 2',
          reason: 'Nested map modification should not affect ${reasons[i]}');
    }
  });

  test('auto generate ID', () async {
    final firestore = FakeFirebaseFirestore();
    final reference1 = firestore.collection('users').doc();
    final document1Id = reference1.id;
    final reference2 = firestore.collection('users').doc();
    expect(document1Id, isNot(reference2.id));

    await reference1.set({
      'someField': 'someValue',
    });
    final snapshot1 = await reference1.get();
    expect(snapshot1.exists, true);
    // reference2 is not saved
    final snapshot2 = await reference2.get();
    expect(snapshot2.exists, false);

    final snapshot = await firestore.collection('users').doc(document1Id).get();
    expect(snapshot.get('someField'), 'someValue');

    final querySnapshot = await firestore.collection('users').get();
    expect(querySnapshot.docs, hasLength(1));
    expect(querySnapshot.docs.first.get('someField'), 'someValue');
  });

  test('Snapshot before saving data', () async {
    final firestore = FakeFirebaseFirestore();
    // These docs are not saved
    final nonExistentId = 'salkdjfaarecikvdiko0';
    final snapshot1 =
        await firestore.collection('users').doc(nonExistentId).get();
    expect(snapshot1, isNotNull);
    expect(snapshot1.id, nonExistentId);
    expect(snapshot1.data(), isNull);
    expect(snapshot1.exists, false);

    final snapshot2 = await firestore.collection('users').doc().get();
    expect(snapshot2, isNotNull);
    expect(snapshot2.id.length, greaterThanOrEqualTo(20));
    expect(snapshot2.exists, false);
  });

  test('Snapshot should remain after updating data', () async {
    final firestore = FakeFirebaseFirestore();
    // These docs are not saved
    final reference = firestore.collection('users').doc('foo');
    await reference.set(<String, dynamic>{'name': 'old'});
    await reference.update(<String, dynamic>{
      'nested.data.message': 'old nested data',
    });

    final snapshot = await reference.get();

    await reference.set(<String, dynamic>{'name': 'new'});
    await reference.update(<String, dynamic>{
      'nested.data.message': 'new nested data',
    });

    // At the time the snapshot was created, the value was 'old'
    expect(snapshot.get('name'), 'old');
    final nested = snapshot.get('nested') as Map<String, dynamic>;
    final nestedData = nested['data'] as Map<String, dynamic>;
    expect(nestedData['message'], 'old nested data');
  });

  test('Batch set', () async {
    final firestore = FakeFirebaseFirestore();
    final foo = firestore.collection('users').doc('foo');
    final bar = firestore.collection('users').doc('bar');

    final batch = firestore.batch();
    batch.set(foo, <String, dynamic>{'name.firstName': 'Foo'});
    batch.set(bar, <String, dynamic>{'name.firstName': 'Bar'});
    await batch.commit();

    final docs = await firestore.collection('users').get();
    expect(docs.docs, hasLength(2));

    final firstNames = docs.docs.map((user) {
      final nameMap = user.get('name') as Map<String, dynamic>;
      return nameMap['firstName'];
    });
    expect(firstNames, containsAll(['Foo', 'Bar']));
  });

  test('Batch update', () async {
    final firestore = FakeFirebaseFirestore();
    final foo = firestore.collection('users').doc('foo');
    await foo.set(<String, dynamic>{'name.firstName': 'OldValue Foo'});
    final bar = firestore.collection('users').doc('bar');
    await foo.set(<String, dynamic>{'name.firstName': 'OldValue Bar'});

    final batch = firestore.batch();
    batch.update(foo, <String, dynamic>{'name.firstName': 'Foo'});
    batch.update(bar, <String, dynamic>{'name.firstName': 'Bar'});
    await batch.commit();

    final docs = await firestore.collection('users').get();
    expect(docs.docs, hasLength(2));

    final firstNames = docs.docs.map((user) {
      final nameMap = user.get('name') as Map<String, dynamic>;
      return nameMap['firstName'];
    });
    expect(firstNames, containsAll(['Foo', 'Bar']));
  });

  test('Batch delete', () async {
    final firestore = FakeFirebaseFirestore();
    final foo = firestore.collection('users').doc('foo');
    await foo.set(<String, dynamic>{'name.firstName': 'Foo'});
    final bar = firestore.collection('users').doc('bar');
    await foo.set(<String, dynamic>{'name.firstName': 'Bar'});

    await firestore
        .collection('users')
        .doc()
        .set(<String, dynamic>{'name.firstName': 'Survivor'});

    final batch = firestore.batch();
    batch.delete(foo);
    batch.delete(bar);
    await batch.commit();

    final docs = await firestore.collection('users').get();
    expect(docs.docs, hasLength(1));
    final savedFoo = docs.docs.first;
    final nameMap = savedFoo.get('name') as Map<String, dynamic>;
    expect(nameMap['firstName'], 'Survivor');
  });

  test('FakeFirebaseFirestore.document with a valid path', () async {
    final firestore = FakeFirebaseFirestore();
    final documentReference = firestore.doc('users/1234');
    expect(documentReference, isNotNull);
  });

  test('FakeFirebaseFirestore.document with an invalid path', () async {
    final firestore = FakeFirebaseFirestore();

    // This should fail because users (1 segments) and users/1234/friends (3 segments)
    // are a reference to a subcollection, not a document.
    // In real Firestore, the behavior of this error depends on the platforms;
    // in iOS, it's NSInternalInconsistencyException that would terminate
    // the app. This library imitates it with assert().
    // https://github.com/atn832/fake_cloud_firestore/issues/30
    expect(() => firestore.doc('users'), throwsA(isA<AssertionError>()));

    // subcollection
    expect(() => firestore.doc('users/1234/friends'),
        throwsA(isA<AssertionError>()));
  });

  test('FakeFirebaseFirestore.collection with an invalid path', () async {
    final firestore = FakeFirebaseFirestore();

    // This should fail because users/1234 (2 segments) is a reference to a
    // document, not a collection.
    expect(() => firestore.collection('users/1234'),
        throwsA(isA<AssertionError>()));

    expect(() => firestore.collection('users/1234/friends/567'),
        throwsA(isA<AssertionError>()));
  });

  test('Transaction set, update, and delete', () async {
    final firestore = FakeFirebaseFirestore();
    final foo = firestore.collection('messages').doc('foo');
    final bar = firestore.collection('messages').doc('bar');
    final baz = firestore.collection('messages').doc('baz');
    await foo.set(<String, dynamic>{'name': 'Foo'});
    await bar.set(<String, dynamic>{'name': 'Bar'});
    await baz.set(<String, dynamic>{'name': 'Baz'});

    final result = await firestore.runTransaction((Transaction tx) async {
      final snapshot = await tx.get(foo);

      tx.set(foo, <String, dynamic>{
        'name': snapshot.get('name') + 'o',
      });
      tx.update(bar, <String, dynamic>{
        'nested.field': 123,
      });
      tx.delete(baz);
      return <String, dynamic>{'k': 'v'};
    });
    expect(result['k'], 'v');

    final updatedSnapshotFoo = await foo.get();
    expect(updatedSnapshotFoo.get('name'), 'Fooo');

    final updatedSnapshotBar = await bar.get();
    final nestedDocument =
        updatedSnapshotBar.get('nested') as Map<String, dynamic>;
    expect(nestedDocument['field'], 123);

    final deletedSnapshotBaz = await baz.get();
    expect(deletedSnapshotBaz.exists, false);
  });

  test('Transaction update. runTransaction does not return value.', () async {
    final instance = FakeFirebaseFirestore();
    const user = {'name': 'Bob'};
    final userDocRef = instance.collection('users').doc();
    await userDocRef.set(user);

    await instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDocRef);
      final data = {'name': 'Mr. ' + snapshot.get('name')};
      transaction.update(userDocRef, data);
      // NOTE: not return value
    });

    final snapshot = await userDocRef.get();
    expect(snapshot.get('name'), 'Mr. Bob');
  });

  test('Transaction: read must come before writes', () async {
    final firestore = FakeFirebaseFirestore();
    final foo = firestore.collection('messages').doc('foo');
    final bar = firestore.collection('messages').doc('bar');
    await foo.set(<String, dynamic>{'name': 'Foo'});
    await bar.set(<String, dynamic>{'name': 'Bar'});

    Future<dynamic> erroneousTransactionUsage() async {
      await firestore.runTransaction((Transaction tx) async {
        final snapshotFoo = await tx.get(foo);

        tx.set(foo, <String, dynamic>{
          'name': snapshotFoo.get('name') + 'o',
        });
        // get cannot come after set
        await tx.get(bar);
      });
    }

    expect(erroneousTransactionUsage, throwsA(isA<PlatformException>()));
  });

  test('Document snapshot data returns a new instance', () async {
    final instance = FakeFirebaseFirestore();
    await instance.collection('users').doc(uid).set({
      'name': 'Eve',
      'friends': ['Alice', 'Bob'],
    });

    final eve = await instance.collection('users').doc(uid).get();
    eve.data()!['name'] = 'John';
    eve.data()!['friends'][0] = 'Superman';

    expect(eve.get('name'), isNot('John')); // nothing changed
    expect(eve.get('friends'), equals(['Alice', 'Bob'])); // nothing changed
  });

  test('CollectionGroup get', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.doc('foo/foo_1/bar/bar_1').set({'value': '1'});
    await firestore.doc('foo/foo_2/bar/bar_2').set({'value': '2'});
    await firestore.doc('bar/bar_3').set({'value': '3'});
    final querySnapshot = await firestore.collectionGroup('bar').get();
    expect(querySnapshot.docs, hasLength(3));
    expect(querySnapshot.docs.first.id, 'bar_3');
    expect(querySnapshot.docs.first.reference.path, 'bar/bar_3');
    expect(querySnapshot.docs.first.data(), {'value': '3'});
    expect(querySnapshot.docs[1].data(), {'value': '1'});
    expect(querySnapshot.docs[2].data(), {'value': '2'});
  });

  test('CollectionGroup get all at same level', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.doc('foo/foo_3/bar/bar_3').set({'value': '3'});
    await firestore.doc('foo/foo_1/bar/bar_1').set({'value': '1'});
    await firestore.doc('foo/foo_2/bar/bar_2').set({'value': '2'});
    final querySnapshot = await firestore.collectionGroup('bar').get();
    expect(querySnapshot.docs, hasLength(3));
    expect(querySnapshot.docs.first.id, 'bar_3');
    expect(querySnapshot.docs.first.reference.path, 'foo/foo_3/bar/bar_3');
    expect(querySnapshot.docs.first.data(), {'value': '3'});
    expect(querySnapshot.docs[1].data(), {'value': '1'});
    expect(querySnapshot.docs[2].data(), {'value': '2'});
  });

  test('CollectionGroup snapshots', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.doc('foo/foo_1/bar/bar_1').set({'value': '1'});
    await firestore.doc('foo/foo_2/bar/bar_2').set({'value': '2'});
    await firestore.doc('bar/bar_3').set({'value': '3'});
    expect(
        firestore.collectionGroup('bar').snapshots(),
        emits(QuerySnapshotMatcher([
          DocumentSnapshotMatcher('bar_3', {'value': '3'}),
          DocumentSnapshotMatcher('bar_1', {'value': '1'}),
          DocumentSnapshotMatcher('bar_2', {'value': '2'}),
        ])));
  });
  test(
      'A sub-collection and a document property with identical names can coexist',
      () async {
    final firestore = FakeFirebaseFirestore();

    // We add a document to a sub-collection. We obviously expect that document
    // to exist, even though intermediate docs/collections don't.
    await firestore
        .collection('santa-claus-todo')
        .doc('family-1')
        .collection('children')
        .doc('child-1')
        .set({'gift': 'Princess dress'});
    expect(
        firestore
            .collection('santa-claus-todo')
            .doc('family-1')
            .collection('children')
            .snapshots(),
        emits(QuerySnapshotMatcher([
          DocumentSnapshotMatcher('child-1', {
            'gift': 'Princess dress',
          })
        ])));

    // Now we set data for a document on the path to the document created
    // above. The new data has a property whose name is identical to the
    // sub-collection. They should not conflict and we can query both.
    await firestore
        .collection('santa-claus-todo')
        .doc('family-1')
        .set({'children': 3});
    expect(
        firestore.collection('santa-claus-todo').snapshots(),
        emits(QuerySnapshotMatcher([
          DocumentSnapshotMatcher('family-1', {
            'children': 3,
          })
        ])));
    expect(
        firestore
            .collection('santa-claus-todo')
            .doc('family-1')
            .collection('children')
            .snapshots(),
        emits(QuerySnapshotMatcher([
          DocumentSnapshotMatcher('child-1', {
            'gift': 'Princess dress',
          })
        ])));
  });

  group('Converters', () {
    final from = (snapshot, _) => Movie()..title = snapshot['title'];
    final to = (Movie movie, _) => {'title': movie.title};
    const MovieTitle = 'Best Movie';

    test('add doc', () async {
      final firestore = FakeFirebaseFirestore();

      final docRef = await firestore
          .collection('movies')
          .withConverter(fromFirestore: from, toFirestore: to)
          .add(Movie()..title = MovieTitle);

      final snapshot = await docRef.get();
      final movie = snapshot.data();
      expect(movie, isNotNull);
      expect(movie!.title, equals(MovieTitle));
    });

    test('doc.set and doc.snapshot', () async {
      final firestore = FakeFirebaseFirestore();
      final docRef = firestore
          .collection('movies')
          .doc(uid)
          .withConverter(fromFirestore: from, toFirestore: to);
      final docSnapshots = docRef.snapshots();
      await docRef.set(Movie()..title = MovieTitle);
      docSnapshots.listen(expectAsync1((snapshot) {
        expect(snapshot.exists, equals(true));
        expect(snapshot.data()!.title, equals(MovieTitle));
      }));
    });

    test('snapshot on both the unconverted and converted doc', () async {
      final firestore = FakeFirebaseFirestore();
      final rawDocRef = firestore.collection('movies').doc(uid);
      final convertedDocRef =
          rawDocRef.withConverter(fromFirestore: from, toFirestore: to);
      await convertedDocRef.set(Movie()..title = MovieTitle);

      rawDocRef.snapshots().listen(expectAsync1((snapshot) {
        expect(snapshot.exists, equals(true));
        expect(snapshot.data()!['title'], equals(MovieTitle));
      }));
      convertedDocRef.snapshots().listen(expectAsync1((snapshot) {
        expect(snapshot.exists, equals(true));
        expect(snapshot.data()!.title, equals(MovieTitle));
      }));
    });

    test('collection snapshot', () async {
      final firestore = FakeFirebaseFirestore();
      final collectionRef = firestore
          .collection('movies')
          .withConverter(fromFirestore: from, toFirestore: to);
      await collectionRef.add(Movie()..title = MovieTitle);
      collectionRef.snapshots().listen(expectAsync1((snapshot) {
        expect(snapshot.size, equals(1));
        expect(snapshot.docs.first.data().title, equals(MovieTitle));
      }));
    });

    test('collection snapshot for both raw and converted', () async {
      final firestore = FakeFirebaseFirestore();
      final rawCollectionRef = firestore.collection('movies');
      final convertedCollectionRef =
          rawCollectionRef.withConverter(fromFirestore: from, toFirestore: to);
      await convertedCollectionRef.add(Movie()..title = MovieTitle);

      rawCollectionRef.snapshots().listen(expectAsync1((snapshot) {
        expect(snapshot.size, equals(1));
        expect(snapshot.docs.first.data()['title'], equals(MovieTitle));
      }));
      convertedCollectionRef.snapshots().listen(expectAsync1((snapshot) {
        expect(snapshot.size, equals(1));
        expect(snapshot.docs.first.data().title, equals(MovieTitle));
      }));
    });

    test('read collection', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('movies')
          .withConverter(fromFirestore: from, toFirestore: to)
          .add(Movie()..title = MovieTitle);

      final nonTypedMovies = firestore.collection('movies');
      expect((await nonTypedMovies.get()).size, equals(1));
      // Query<Movie>
      final typedMovies = await nonTypedMovies
          .withConverter(fromFirestore: from, toFirestore: to)
          .get();
      expect(typedMovies.size, equals(1));
      expect(typedMovies.docs.first.data().title, equals(MovieTitle));
    });

    test('search docs', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('movies')
          .withConverter(fromFirestore: from, toFirestore: to)
          .add(Movie()..title = MovieTitle);

      // Query<Map<String, dynamic>>
      final nonTypedMoviesQuery =
          firestore.collection('movies').where('title', isNull: false);
      expect((await nonTypedMoviesQuery.get()).docs.first.data()['title'],
          equals(MovieTitle));
      // QuerySnapshot<Movie>
      final typedMovies = await nonTypedMoviesQuery
          .withConverter(fromFirestore: from, toFirestore: to)
          .get();

      expect(typedMovies.size, equals(1));
      expect(typedMovies.docs.first.data().title, equals(MovieTitle));
    });

    test('query snapshot for both raw and converted', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('movies')
          .withConverter(fromFirestore: from, toFirestore: to)
          .add(Movie()..title = MovieTitle);

      // Query<Map<String, dynamic>>
      final rawMoviesQuery =
          firestore.collection('movies').where('title', isNull: false);
      expect((await rawMoviesQuery.get()).docs.first.data()['title'],
          equals(MovieTitle));
      // QuerySnapshot<Movie>
      final typedMoviesQuery =
          rawMoviesQuery.withConverter(fromFirestore: from, toFirestore: to);

      rawMoviesQuery.snapshots().listen(expectAsync1((snapshot) {
        expect(snapshot.size, equals(1));
        expect(snapshot.docs.first.data()['title'], equals(MovieTitle));
      }));
      typedMoviesQuery.snapshots().listen(expectAsync1((snapshot) {
        expect(snapshot.size, equals(1));
        expect(snapshot.docs.first.data().title, equals(MovieTitle));
      }));
    });
  });
}

class Movie {
  late String title;
}
