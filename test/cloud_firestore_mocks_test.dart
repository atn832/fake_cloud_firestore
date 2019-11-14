import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';
import 'package:test/test.dart';

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

const uid = 'abc';

void main() {
  group('A group of tests', () {
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
            DocumentSnapshotMatcher('z', {
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
}

class QuerySnapshotMatcher implements Matcher {
  List<DocumentSnapshotMatcher> _documentSnapshotMatchers;

  QuerySnapshotMatcher(this._documentSnapshotMatchers);

  @override
  Description describe(Description description) {
    return StringDescription("Matches a query snapshot's DocumentSnapshots.");
  }

  @override
  Description describeMismatch(
      item, Description mismatchDescription, Map matchState, bool verbose) {
    mismatchDescription.add("Snapshot does not match expected data.");

    // TODO: this will crash if there are fewer matchers than documents.

    final snapshot = item as QuerySnapshot;
    for (var i = 0; i < snapshot.documents.length; i++) {
      final matcher = _documentSnapshotMatchers[i];
      final item = snapshot.documents[i];
      if (!matcher.matches(item, matchState)) {
        matcher.describeMismatch(
            item, mismatchDescription, matchState, verbose);
      }
    }
    return mismatchDescription;
  }

  @override
  bool matches(item, Map matchState) {
    final snapshot = item as QuerySnapshot;
    if (snapshot.documents.length != _documentSnapshotMatchers.length) {
      return false;
    }
    for (var i = 0; i < snapshot.documents.length; i++) {
      final matcher = _documentSnapshotMatchers[i];
      if (!matcher.matches(snapshot.documents[i], matchState)) {
        return false;
      }
    }
    return true;
  }
}

class DocumentSnapshotMatcher implements Matcher {
  String _documentId;
  Map<String, dynamic> _data;

  DocumentSnapshotMatcher(this._documentId, this._data);

  @override
  Description describe(Description description) {
    return StringDescription("Matches a snapshot's documentId and data");
  }

  @override
  Description describeMismatch(
      item, Description mismatchDescription, Map matchState, bool verbose) {
    final snapshot = item as DocumentSnapshot;
    // TODO: generate more meaningful descriptions.
    if (!equals(snapshot.documentID).matches(_documentId, matchState)) {
      equals(snapshot.documentID).describeMismatch(
          _documentId, mismatchDescription, matchState, verbose);
    }
    if (!equals(snapshot.data).matches(_data, matchState)) {
      equals(snapshot.data)
          .describeMismatch(_data, mismatchDescription, matchState, verbose);
    }
    return mismatchDescription;
  }

  @override
  bool matches(item, Map matchState) {
    final snapshot = item as DocumentSnapshot;
    return equals(snapshot.documentID).matches(_documentId, matchState) &&
        equals(snapshot.data).matches(_data, matchState);
  }
}
