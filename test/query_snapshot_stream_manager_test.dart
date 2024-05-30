import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fake_cloud_firestore/src/mock_query_snapshot.dart';
import 'package:test/test.dart';

class User {
  final String name;

  User(this.name);

  User.fromMap(Map<String, dynamic> map) : name = map['name'];

  Map<String, dynamic> toFirestore() => {
        'name': name,
      };
}

void main() {
  late FakeFirebaseFirestore instance;

  setUp(() async {
    instance = FakeFirebaseFirestore();
  });

  group('cache modifications', () {
    setUp(() async {
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
  });

  group('listener updates', () {
    late CollectionReference collectionRef;
    setUp(() {
      collectionRef = instance.collection('users');
    });

    void validateSnapshotsWithoutConverter() {
      expect(
        collectionRef.snapshots(),
        emitsInOrder(
          [
            isA<MockQuerySnapshot<Map<String, dynamic>>>().having(
                (event) => (event.docs.first.data() as Map)['name'],
                'has correct name',
                'Bob'),
            isA<MockQuerySnapshot<Map<String, dynamic>>>().having(
                (event) => (event.docs.first.data() as Map)['name'],
                'has correct name',
                'Marie'),
          ],
        ),
      );
    }

    test('can receive updates', () async {
      await collectionRef.doc('1').set({
        'name': 'Bob',
      });

      validateSnapshotsWithoutConverter();
      await collectionRef.doc('1').set({
        'name': 'Marie',
      });
    });
    test('can receive updates starting with converter', () async {
      final converterRef = collectionRef.withConverter<User>(
        fromFirestore: (snapshot, options) => User.fromMap(snapshot.data()!),
        toFirestore: (user, options) => user.toFirestore(),
      );
      await converterRef.doc('1').set(User('Bob'));

      validateSnapshotsWithoutConverter();

      await collectionRef.doc('1').set({
        'name': 'Marie',
      });
    });
    test('can receive updates from converter', () async {
      await collectionRef.doc('1').set({
        'name': 'Bob',
      });

      validateSnapshotsWithoutConverter();

      final converterRef = collectionRef.withConverter<User>(
        fromFirestore: (snapshot, options) => User.fromMap(snapshot.data()!),
        toFirestore: (user, options) => user.toFirestore(),
      );
      await converterRef.doc('1').set(User('Marie'));
    });
  });
}
