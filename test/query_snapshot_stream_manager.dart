import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:test/test.dart';

void main() {
  late FakeFirebaseFirestore instance;

  setUp(() async {
    instance = FakeFirebaseFirestore();
    await instance.collection('users').add({
      'name': 'Bob',
    });
    await instance.collection('users').add({
      'name': 'Marie',
      'mentor': 'users/bob_doc',
    });
  });

  /// We're reproducing a foreign key pattern where each document generates a new subscription filtering on itself.
  test('Should allow concurrent cache modifications', () {
    final subscriptions = <StreamSubscription<QuerySnapshot>>[];
    instance.collection('users').snapshots().listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
      for (final docChange in snapshot.docChanges) {
        subscriptions.add(instance
            .collection('users')
            .where('mentor', isEqualTo: docChange.doc.id)
            .snapshots()
            .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {}));
      }

      instance.collection('users').add({
        'name': 'Steve',
        'mentor': 'users/bob_doc',
      });
    });
  });
}
