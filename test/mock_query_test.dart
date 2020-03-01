import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';
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
}
