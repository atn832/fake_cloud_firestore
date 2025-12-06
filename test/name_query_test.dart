import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:test/test.dart';

void main() {
  test('Query by __name__', () async {
    final instance = FakeFirebaseFirestore();
    await instance.collection('users').doc('a').set({'name': 'a'});
    await instance.collection('users').doc('b').set({'name': 'b'});
    await instance.collection('users').doc('c').set({'name': 'c'});

    var snapshot = await instance
        .collection('users')
        .where('__name__', isGreaterThanOrEqualTo: 'users/b')
        .get();

    // This should return 'b' and 'c'.

    expect(snapshot.docs.length, 2);
    expect(snapshot.docs[0].id, 'b');
    expect(snapshot.docs[1].id, 'c');
  });
}
