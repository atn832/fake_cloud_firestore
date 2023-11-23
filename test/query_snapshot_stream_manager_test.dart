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
    });
  });

  test('Should allow concurrent cache modifications', () {
    final subscriptions = <StreamSubscription<QuerySnapshot>>[];
    instance
        .collection('users')
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
      // Add a new listener to the same query while an update being fired. This
      // used to trigger a concurrency error.
      subscriptions.add(instance
          .collection('users')
          .snapshots()
          .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {}));
    });
    // Fire a snapshot update.
    instance.collection('users').add({
      'name': 'Steve',
    });
  });
}
