import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';
import 'package:flutter/services.dart';
import 'package:test/test.dart';
import 'document_snapshot_matcher.dart';
import 'query_snapshot_matcher.dart';

const uid = 'abc';

void main() {
  test('Where(field, isGreaterThan: ...)', () async {
    final instance = MockFirestoreInstance();
    final now = DateTime.now();
    await instance.collection('messages').add({
      'content': 'hello!',
      'uid': uid,
      'timestamp': now,
    });
    // Test that there is one result.
    expect(
        instance
            .collection('messages')
            .where('timestamp',
                isGreaterThan: now.subtract(Duration(seconds: 1)))
            .snapshots(),
        emits(QuerySnapshotMatcher([
          DocumentSnapshotMatcher.onData({
            'content': 'hello!',
            'uid': uid,
            'timestamp': Timestamp.fromDate(now),
          })
        ])));
    // Filter out everything and check that there is no result.
    expect(
        instance
            .collection('messages')
            .where('timestamp', isGreaterThan: now.add(Duration(seconds: 1)))
            .snapshots(),
        emits(QuerySnapshotMatcher([])));
  });

  test('isLessThanOrEqualTo', () async {
    final instance = MockFirestoreInstance();
    final now = DateTime.now();
    final before = now.subtract(Duration(seconds: 1));
    final after = now.add(Duration(seconds: 1));
    await instance.collection('messages').add({
      'content': 'before',
      'timestamp': before,
    });
    await instance.collection('messages').add({
      'content': 'during',
      'timestamp': now,
    });
    await instance.collection('messages').add({
      'content': 'after',
      'timestamp': after,
    });
    // Test filtering.
    expect(
        instance
            .collection('messages')
            .where('timestamp', isLessThanOrEqualTo: now)
            .snapshots(),
        emits(QuerySnapshotMatcher([
          DocumentSnapshotMatcher.onData({
            'content': 'before',
            'timestamp': Timestamp.fromDate(before),
          }),
          DocumentSnapshotMatcher.onData({
            'content': 'during',
            'timestamp': Timestamp.fromDate(now),
          }),
        ])));
    expect(
        instance
            .collection('messages')
            .where('timestamp',
                isLessThanOrEqualTo: now.subtract(Duration(seconds: 2)))
            .snapshots(),
        emits(QuerySnapshotMatcher([])));
    expect(
        instance
            .collection('messages')
            .where('timestamp', isLessThan: now)
            .snapshots(),
        emits(QuerySnapshotMatcher([
          DocumentSnapshotMatcher.onData({
            'content': 'before',
            'timestamp': Timestamp.fromDate(before),
          }),
        ])));
    expect(
        instance
            .collection('messages')
            .where('timestamp', isLessThan: now.subtract(Duration(seconds: 2)))
            .snapshots(),
        emits(QuerySnapshotMatcher([])));
    expect(
        instance
            .collection('messages')
            .where('timestamp', isGreaterThanOrEqualTo: now)
            .snapshots(),
        emits(QuerySnapshotMatcher([
          DocumentSnapshotMatcher.onData({
            'content': 'during',
            'timestamp': Timestamp.fromDate(now),
          }),
          DocumentSnapshotMatcher.onData({
            'content': 'after',
            'timestamp': Timestamp.fromDate(after),
          }),
        ])));
    expect(
        instance
            .collection('messages')
            .where('timestamp',
                isGreaterThanOrEqualTo: now.add(Duration(seconds: 2)))
            .snapshots(),
        emits(QuerySnapshotMatcher([])));
  });

  test('isEqualTo, orderBy, limit and getDocuments', () async {
    final instance = MockFirestoreInstance();
    final now = DateTime.now();
    final bookmarks = await instance
        .collection('users')
        .document(uid)
        .collection('bookmarks');
    await bookmarks.add({
      'hidden': false,
      'timestamp': now,
    });
    await bookmarks.add({
      'tag': 'mostrecent',
      'hidden': false,
      'timestamp': now.add(Duration(days: 1)),
    });
    await bookmarks.add({
      'hidden': false,
      'timestamp': now,
    });
    await bookmarks.add({
      'hidden': true,
      'timestamp': now,
    });
    final snapshot = (await instance
        .collection('users')
        .document(uid)
        .collection('bookmarks')
        .where('hidden', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .limit(2)
        .getDocuments());
    expect(snapshot.documents.length, equals(2));
    expect(snapshot.documents.first['tag'], equals('mostrecent'));
  });

  test('orderBy returns documents with null fields first', () async {
    final instance = MockFirestoreInstance();
    await instance
        .collection('usercourses')
        .add({'completed_at': Timestamp.fromDate(DateTime.now())});
    await instance.collection('usercourses').add({'completed_at': null});

    var query = instance.collection('usercourses').orderBy('completed_at');

    query.snapshots().listen(expectAsync1(
      (event) {
        expect(event.documents[0]['completed_at'], isNull);
        expect(event.documents[1]['completed_at'], isNotNull);
        expect(event.documents.length, greaterThan(0));
      },
    ));
  });

  test('arrayContains', () async {
    final instance = MockFirestoreInstance();
    await instance.collection('posts').add({
      'name': 'Post #1',
      'tags': ['mostrecent', 'interesting'],
    });
    await instance.collection('posts').add({
      'name': 'Post #2',
      'tags': ['mostrecent'],
    });
    await instance.collection('posts').add({
      'name': 'Post #3',
      'tags': ['mostrecent'],
    });
    await instance.collection('posts').add({
      'name': 'Post #4',
      'tags': ['mostrecent', 'interesting'],
    });
    instance
        .collection('posts')
        .where('tags', arrayContains: 'interesting')
        .snapshots()
        .listen(expectAsync1((QuerySnapshot snapshot) {
      expect(snapshot.documents.length, equals(2));

      /// verify the matching documents were returned
      snapshot.documents.forEach((returnedDocument) {
        expect(returnedDocument.data['tags'], contains('interesting'));
      });
    }));
  });

  test('arrayContainsAny', () async {
    final instance = MockFirestoreInstance();
    await instance.collection('posts').add({
      'name': 'Post #1',
      'tags': ['mostrecent', 'interesting', 'coolstuff'],
      'commenters': [111, 222, 333],
    });
    await instance.collection('posts').add({
      'name': 'Post #2',
      'tags': ['mostrecent'],
      'commenters': [111, 222],
    });
    await instance.collection('posts').add({
      'name': 'Post #3',
      'tags': ['mostrecent'],
      'commenters': [111],
    });
    await instance.collection('posts').add({
      'name': 'Post #4',
      'tags': ['mostrecent', 'interesting'],
      'commenters': [222, 333]
    });
    instance
        .collection('posts')
        .where('tags', arrayContainsAny: ['interesting', 'mostrecent'])
        .snapshots()
        .listen(expectAsync1((QuerySnapshot snapshot) {
          expect(snapshot.documents.length, equals(4));
        }));
    instance
        .collection('posts')
        .where('commenters', arrayContainsAny: [222, 333])
        .snapshots()
        .listen(expectAsync1((QuerySnapshot snapshot) {
          expect(snapshot.documents.length, equals(3));
        }));
    instance
        .collection('posts')
        .where(
          'commenters',
          arrayContainsAny: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
        )
        .snapshots()
        .listen(null, onError: expectAsync1((error) {
          expect(error, isA<ArgumentError>());
        }));
  });

  test('whereIn', () async {
    final instance = MockFirestoreInstance();
    await instance.collection('contestants').add({
      'name': 'Alice',
      'country': 'USA',
      'skills': ['cycling', 'running']
    });
    await instance.collection('contestants').add({
      'name': 'Bob',
      'country': 'Japan',
      'skills': ['gymnastics', 'swimming']
    });
    await instance.collection('contestants').add({
      'name': 'Celina',
      'country': 'India',
      'skills': ['swimming', 'running']
    });
    instance
        .collection('contestants')
        .where('country', whereIn: ['Japan', 'India'])
        .snapshots()
        .listen(expectAsync1((QuerySnapshot snapshot) {
          expect(snapshot.documents.length, equals(2));
        }));
    instance
        .collection('contestants')
        .where('country', whereIn: ['USA'])
        .snapshots()
        .listen(expectAsync1((QuerySnapshot snapshot) {
          expect(snapshot.documents.length, equals(1));
        }));
    instance
        .collection('contestants')
        .where(
          'country',
          whereIn: ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'],
        )
        .snapshots()
        .listen(null, onError: expectAsync1((error) {
          expect(error, isA<ArgumentError>());
        }));
    instance
        .collection('contestants')
        .where(
          'country',
          whereIn: ['India'],
          arrayContainsAny: ['USA'],
        )
        .snapshots()
        .listen(null, onError: expectAsync1((error) {
          expect(error, isFormatException);
        }));
  });

  test('Collection.getDocuments', () async {
    final instance = MockFirestoreInstance();
    await instance.collection('users').add({
      'username': 'Bob',
    });
    final snapshot = await instance.collection('users').getDocuments();
    expect(snapshot.documents.length, equals(1));
  });

  test('Chained where queries return the correct snapshots', () async {
    final instance = MockFirestoreInstance();
    final bookmarks = await instance
        .collection('users')
        .document(uid)
        .collection('bookmarks');
    await bookmarks.add({
      'hidden': false,
    });
    await bookmarks.add({
      'tag': 'mostrecent',
      'hidden': false,
    });
    await bookmarks.add({
      'hidden': false,
    });
    await bookmarks.add({
      'tag': 'mostrecent',
      'hidden': true,
    });
    instance
        .collection('users')
        .document(uid)
        .collection('bookmarks')
        .where('hidden', isEqualTo: false)
        .where('tag', isEqualTo: 'mostrecent')
        .snapshots()
        .listen(expectAsync1((QuerySnapshot snapshot) {
      expect(snapshot.documents.length, equals(1));
      expect(snapshot.documents.first.data['tag'], equals('mostrecent'));
    }));
  });

  test('Collection reference should not hold query result', () async {
    final instance = MockFirestoreInstance();

    final collectionReference = instance.collection('users');
    await collectionReference.add({
      'username': 'Bob',
    });
    final snapshot = await collectionReference.getDocuments();
    expect(snapshot.documents, hasLength(1));
  });

  test('Reference to subcollection should not hold query result', () async {
    final instance = MockFirestoreInstance();

    final collectionReference = instance.collection('users/1234/friends');
    await collectionReference.document('abc').setData({
      'username': 'Bob',
    });
    final snapshot = await collectionReference.getDocuments();
    expect(snapshot.documents, hasLength(1));

    await collectionReference.document('abc').delete();
    final snapshotAfterDelete = await collectionReference.getDocuments();
    expect(snapshotAfterDelete.documents, hasLength(0));
  });

  test('Query should not hold query result', () async {
    final instance = MockFirestoreInstance();

    final collectionReference = instance.collection('users/1234/friends');
    final query1 = collectionReference.where('username', isGreaterThan: 'B');
    final query2 = query1.orderBy('username');
    final query3 = query2.limit(1);

    final snapshotBeforeAdd = await query3.getDocuments();
    expect(snapshotBeforeAdd.documents, isEmpty);

    await collectionReference.add({
      'username': 'Alex',
    });
    await collectionReference.add({
      'username': 'Charlie',
    });
    await collectionReference.add({
      'username': 'Brian',
    });

    final snapshotAfterAdd = await query3.getDocuments();
    expect(snapshotAfterAdd.documents, hasLength(1)); // limit 1
    // Alex is filtered out by 'where' query.
    // 'Brian' comes before 'Charlie'
    expect(snapshotAfterAdd.documents.first.data['username'], 'Brian');
  });

  test('StartAfterDocument', () async {
    final instance = MockFirestoreInstance();

    await instance
        .collection('messages')
        .document()
        .setData({'Username': 'Alice'});

    await instance
        .collection('messages')
        .document(uid)
        .setData({'Username': 'Bob'});

    await instance
        .collection('messages')
        .document()
        .setData({'Username': 'Cris'});

    await instance
        .collection('messages')
        .document()
        .setData({'Username': 'John'});

    final documentSnapshot =
        await instance.collection('messages').document(uid).get();

    final snapshots = await instance
        .collection('messages')
        .startAfterDocument(documentSnapshot)
        .getDocuments();

    expect(snapshots.documents, hasLength(2));
    expect(
      snapshots.documents.where(
        (doc) {
          return doc.documentID == uid;
        },
      ),
      hasLength(0),
    );
  });

  test('chaining where and startAfterDocument return correct documents',
      () async {
    final instance = MockFirestoreInstance();

    await instance
        .collection('messages')
        .document()
        .setData({'username': 'Bob'});

    await instance //Start after this doc
        .collection('messages')
        .document(uid)
        .setData({'username': 'Bob'});

    await instance
        .collection('messages')
        .document()
        .setData({'username': 'John'});

    await instance
        .collection('messages')
        .document()
        .setData({'username': 'Bob'});

    final documentSnapshot =
        await instance.collection('messages').document(uid).get();

    final querySnapshot = await instance
        .collection('messages')
        .where('username', isEqualTo: 'Bob')
        .startAfterDocument(documentSnapshot)
        .getDocuments();

    expect(querySnapshot.documents, hasLength(1));
  });

  test('startAfterDocument throws if the document doesn\'t exist', () async {
    final instance = MockFirestoreInstance();

    await instance
        .collection('messages')
        .document(uid)
        .setData({'username': 'Bob'});

    final documentSnapshot =
        await instance.collection('messages').document(uid).get();

    await instance.collection('123').document().setData({'tag': 'bike'});

    await instance.collection('123').document().setData({'tag': 'chess'});

    expect(
      () async => await instance
          .collection('123')
          .startAfterDocument(documentSnapshot)
          .getDocuments(),
      throwsA(TypeMatcher<PlatformException>()),
    );
  });

  test('Continuous data receive via stream with where', () async {
    final instance = MockFirestoreInstance();
    instance
        .collection('messages')
        .where('archived', isEqualTo: false)
        .snapshots()
        .listen(expectAsync1((snapshot) {
          expect(snapshot.documents.length, inInclusiveRange(0, 2));
          for (var d in snapshot.documents) {
            expect(d.data['archived'], isFalse);
          }
        }, count: 3)); // initial [], when add 'hello!' and when add 'hola!'.

    instance
        .collection('messages')
        .where('archived', isEqualTo: true)
        .snapshots()
        .listen(expectAsync1((snapshot) {
          expect(snapshot.documents.length, inInclusiveRange(0, 1));
          for (var d in snapshot.documents) {
            expect(d.data['archived'], isTrue);
          }
        }, count: 2)); // initial [], when add 'hello!' and when add 'hola!'.

    // this should be received.
    await instance.collection('messages').add({
      'content': 'hello!',
      'archived': false,
    });

    // this should not be received because of archived == true.
    await instance.collection('messages').add({
      'content': 'bonjour!',
      'archived': true,
    });

    // this should be received.
    await instance.collection('messages').add({
      'content': 'hola!',
      'archived': false,
    });

    // check new stream will receive the latest data.
    instance
        .collection('messages')
        .where('archived', isEqualTo: false)
        .snapshots()
        .listen(expectAsync1((snapshot) {
      expect(snapshot.documents.length, equals(2));
      for (var d in snapshot.documents) {
        expect(d.data['archived'], isFalse);
      }
    }));
  });

  test('Continuous data receive via stream with orderBy (asc and desc)',
      () async {
    final now = DateTime.now();
    final testData = <Map<String, dynamic>>[
      {'content': 'hello!', 'receivedAt': now, 'archived': false},
      {
        'content': 'bonjour!',
        'receivedAt': now.add(const Duration(seconds: 1)),
        'archived': true,
      },
      {
        'content': 'hola!',
        'receivedAt': now.subtract(const Duration(seconds: 1)),
        'archived': false,
      }
    ];

    final ascendingContnts = [
      ['hello!'],
      ['hello!', 'bonjour!'],
      ['hola!', 'hello!', 'bonjour!'],
    ];

    final descendingContnts = [
      ['hello!'],
      ['bonjour!', 'hello!'],
      ['bonjour!', 'hello!', 'hola!'],
    ];

    final instance = MockFirestoreInstance();
    var ascendingCalled = 0;
    instance
        .collection('messages')
        .orderBy('receivedAt')
        .snapshots()
        .listen(expectAsync1((snapshot) {
          try {
            if (ascendingCalled == 0) {
              expect(snapshot.documents, isEmpty);
              return;
            } else {
              expect(snapshot.documents.length,
                  inInclusiveRange(1, testData.length));
            }
            for (var i = 0; i < snapshot.documents.length; i++) {
              expect(
                snapshot.documents[i].data['content'],
                equals(ascendingContnts[ascendingCalled - 1][i]),
              );
            }
          } finally {
            ascendingCalled++;
          }
        }, count: testData.length + 1));
    var descendingCalled = 0;
    instance
        .collection('messages')
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .listen(expectAsync1((snapshot) {
          try {
            if (descendingCalled == 0) {
              expect(snapshot.documents, isEmpty);
              return;
            } else {
              expect(snapshot.documents.length,
                  inInclusiveRange(0, testData.length));
            }
            for (var i = 0; i < snapshot.documents.length; i++) {
              expect(
                snapshot.documents[i].data['content'],
                equals(descendingContnts[descendingCalled - 1][i]),
              );
            }
          } finally {
            descendingCalled++;
          }
        }, count: testData.length + 1));

    await instance.collection('messages').add(testData[0]);
    await instance.collection('messages').add(testData[1]);
    await instance.collection('messages').add(testData[2]);
  });
}
