import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';
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

const expectedDumpAfterAddData = """{
  "messages": {
    "z": {
      "content": "hello!",
      "uid": "abc"
    }
  }
}""";

const expectedDumpAfterSuccessiveAddData = """{
  "messages": {
    "z": {
      "content": "hello!",
      "uid": "abc"
    },
    "zz": {
      "content": "there!",
      "uid": "abc"
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
      await instance.collection('messages').add({
        'content': 'hello!',
        'uid': uid,
      });
      expect(instance.dump(), equals(expectedDumpAfterAddData));
      await instance.collection('messages').add({
        'content': 'there!',
        'uid': uid,
      });
      expect(instance.dump(), equals(expectedDumpAfterSuccessiveAddData));
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

  test('Creating document reference should not save the document',
      () async {
    final instance = MockFirestoreInstance();
    await instance.collection('users').add(<String, dynamic>{
      'name' : 'Foo'
    });
    final documentReference = instance.collection('users').document(uid);

    var querySnapshot = await instance
        .collection('users').getDocuments();
    expect(querySnapshot.documents, hasLength(1));

    // Only after setData, the document is available for getDocuments
    await documentReference.setData({'name': 'Bar'});
    querySnapshot = await instance
        .collection('users').getDocuments();
    expect(querySnapshot.documents, hasLength(2));
  });

  test('Saving documents in subcollection',
      () async {
    final instance = MockFirestoreInstance();
    await instance.collection('users').document(uid).collection('friends').add(<String, dynamic>{
      'name' : 'Foo'
    });

    final documentReference = instance.collection('users')
    .document(uid).collection('friends').document();

    final subcollection = instance.collection('users').document(uid).collection('friends');
    var querySnapshot = await subcollection.getDocuments();
    expect(querySnapshot.documents, hasLength(1));

    // Only after setData, the document is available for getDocuments
    await documentReference.setData({'name': 'Bar'});
    querySnapshot = await subcollection.getDocuments();
    expect(querySnapshot.documents, hasLength(2));
  });

  test('Snapshots returns a Stream of Snapshots upon each change', () async {
    final instance = MockFirestoreInstance();
    expect(
        instance.collection('users').snapshots(),
        emits(QuerySnapshotMatcher([
          DocumentSnapshotMatcher('z', {
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
          DocumentSnapshotMatcher('z', {
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
  });

  group('FieldValue', () {
    test('FieldValue.delete() deletes key values', () async {
      final firestore = MockFirestoreInstance();
      await firestore.document('root').setData({'flower': 'rose'});
      await firestore.document('root').setData({'flower': FieldValue.delete()});
      final document = await firestore.document('root').get();
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
      // Mock is fast. It shouldn't take 1000 milliseconds to execute the code above
      expect(timeDiff, lessThan(1000));
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
    // Mock is fast. It shouldn't take 1000 milliseconds to execute the code above
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
    // TODO: assert result length size. It should be 1.
    // https://github.com/atn832/cloud_firestore_mocks/issues/20
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
    // TODO: data field should be null before the document is saved
    // https://github.com/atn832/cloud_firestore_mocks/issues/21
    // expect(snapshot1.data, isNull);
    expect(snapshot1.exists, false);

    final snapshot2 = await firestore.collection('users').document().get();
    expect(snapshot2, isNotNull);
    expect(snapshot2.documentID.length, 20);
    expect(snapshot2.exists, false);
  });
}
