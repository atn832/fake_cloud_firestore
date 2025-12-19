import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:test/test.dart';

void main() {
  test('Query by __name__', () async {
    final instance = FakeFirebaseFirestore();
    await instance.collection('users').doc('a').set({'firstName': 'Alice'});
    await instance.collection('users').doc('b').set({'firstName': 'Bob'});
    await instance.collection('users').doc('c').set({'firstName': 'Charlie'});

    var snapshot = await instance
        .collection('users')
        .where('__name__', isGreaterThanOrEqualTo: 'users/b')
        .get();

    // This should return 'b' and 'c'.

    expect(snapshot.docs.length, 2);
    expect(snapshot.docs[0].id, 'b');
    expect(snapshot.docs[1].id, 'c');
  });

  /// In this test, Alice is in organisation-1, Bob and Charlie are in organisation-2.
  /// Users are siloed by both organisation and project.
  test('Query collection group by __name__', () async {
    final instance = FakeFirebaseFirestore();
    await instance
        .doc('organisations/organisation-1/projects/project-1/users/a')
        .set({'firstName': 'Alice'});
    await instance
        .doc('organisations/organisation-2/projects/project-1/users/b')
        .set({'firstName': 'Bob'});
    await instance
        .doc('organisations/organisation-2/projects/project-2/users/c')
        .set({'firstName': 'Charlie'});
    await instance
        .doc('organisations/organisation-3/projects/project-1/users/d')
        .set({'firstName': 'Dave'});

    var snapshot = await instance
        .collectionGroup('users')
        .where('__name__',
            isGreaterThanOrEqualTo: 'organisations/organisation-2')
        .where('__name__', isLessThan: 'organisations/organisation-2~')
        .get();

    // This should return 'b' and 'c'.

    expect(snapshot.docs.length, 2);
    expect(snapshot.docs[0].id, 'b');
    expect(snapshot.docs[1].id, 'c');
  });
}
