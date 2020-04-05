import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_test/flutter_test.dart';

import 'field_value_behaviors_parameters.dart';
import 'firestore_clients.dart';

/// Test for FieldValue implementation. This test requires
/// FIRESTORE_IMPLEMENTATION environment variable set to 'cloud_firestore_mocks'
/// or 'cloud_firestore'. For example:
/// FIRESTORE_IMPLEMENTATION=cloud_firestore_mocks flutter drive --target=test_driver/field_value_behaviors.dart
void main() async {
  final Completer<String> firestoreImplementationQuery = Completer<String>();
  final Completer<String> completer = Completer<String>();

  // Receives Firestore implementation choice from Driver program, because this
  // test application running in a device cannot receive environment variables
  // directly from 'flutter drive' command.
  enableFlutterDriverExtension(handler: (message) {
    if (validImplementationNames.contains(message)) {
      firestoreImplementationQuery.complete(message);
      return Future.value(null);
    } else if (message == 'waiting_test_completion') {
      // Have Driver program wait for this future completion at tearDownAll.
      return completer.future;
    } else {
      fail('Unexpected message from Driver: $message');
    }
  });
  tearDownAll(() {
    completer.complete(null);
  });

  firestoreFutures = {
    // cloud_firestore_mocks
    'cloud_firestore_mocks': firestoreImplementationQuery.future.then((value) =>
        value == cloudFirestoreMocksImplementationName
            ? MockFirestoreInstance()
            : null),
    // cloud_firestore backed by Cloud Firestore (project ID:
    // flutter-firestore)
    'Cloud Firestore': firestoreImplementationQuery.future.then((value) =>
        value == cloudFirestoreImplementationName
            ? createFireStoreClient('test', null, true)
            : null),

    // cloud_firestore backed by Firestore Emulator
    'Firestore Emulator': firestoreImplementationQuery.future.then((value) =>
        value == cloudFirestoreImplementationName
            ? createFireStoreClient('test2', 'localhost:8080', false)
            : null),
  };

  group('Firestore behavior on FieldValue:', () {
    ftest('FieldValue.increment', (firestore) async {
      final CollectionReference messages = firestore.collection('messages');

      final DocumentReference doc = messages.document();

      await doc.setData(<String, dynamic>{
        'message': 'hello firestore',
        'int': 3,
        'double': 2.2,
        'previously String': 'foo',
      });

      await doc.updateData(<String, dynamic>{
        'int': FieldValue.increment(2),
        'double': FieldValue.increment(1.7),
        'previously absent': FieldValue.increment(4),
        'previously String': FieldValue.increment(5),
      });

      final snapshot = await doc.get();

      await doc.delete();

      expect(snapshot.data['message'], 'hello firestore');
      expect(snapshot.data['int'], 5);
      expect(snapshot.data['double'], 2.2 + 1.7);
      expect(snapshot.data['previously absent'], 4);
      expect(snapshot.data['previously String'], 5);
    });

    ftest('FieldValue.serverTimestamp', (firestore) async {
      final CollectionReference messages = firestore.collection('messages');

      final DocumentReference doc = messages.document();

      await doc.setData(<String, dynamic>{
        'message': 'hello firestore',
      });

      await doc.updateData(<String, dynamic>{
        'timestamp': FieldValue.serverTimestamp(),
      });

      final snapshot = await doc.get();

      await doc.delete();

      // This assertion depends on computer's clock accuracy compared to
      // Cloud Firestore's server. If this fails, ensure your computer's clock
      // is synchronized automatically.
      expect(
          snapshot.data['timestamp'],
          within(
              from: Timestamp.now(),
              distance: 5000, // 5 seconds
              distanceFunction: (Timestamp t1, Timestamp t2) =>
                  (t2.millisecondsSinceEpoch - t1.millisecondsSinceEpoch)
                      .abs()));
      // Update should not affect irrelevant fields
      expect(snapshot.data['message'], 'hello firestore');
    });

    ftest('FieldValue.delete', (firestore) async {
      final CollectionReference messages = firestore.collection('messages');

      final DocumentReference doc = messages.document();

      await doc
          .setData(<String, dynamic>{'field1': 'hello', 'field2': 'firestore'});

      await doc.updateData(<String, dynamic>{
        'field1': FieldValue.delete(),
      });

      final snapshot = await doc.get();

      await doc.delete();

      expect(snapshot.data['field1'], isNull);
      expect(snapshot.data['field2'], 'firestore');
    });

    ftest('FieldValue.arrayUnion', (firestore) async {
      final CollectionReference messages = firestore.collection('messages');

      final DocumentReference doc = messages.document();

      await doc.setData(<String, dynamic>{
        'array': [1, 2],
        'empty array in document': [],
        'empty array in argument': [4, 5],
        'string and int array': [1, 2, 'three', 'four'],
        'duplicate elements in document': [1, 2, 2],
        'duplicate elements in arguments': [1, 2, 3],
        'previously String': 'foo',
      });

      await doc.updateData(<String, dynamic>{
        'array': FieldValue.arrayUnion([1, 3]),
        'empty array in document': FieldValue.arrayUnion([1, 2, 3]),
        'empty array in argument': FieldValue.arrayUnion([]),
        'string and int array': FieldValue.arrayUnion([2, 'five', 6]),
        'duplicate elements in document': FieldValue.arrayUnion([2, 3, 4]),
        'duplicate elements in arguments': FieldValue.arrayUnion([4, 3, 4, 5]),
        'previously String': FieldValue.arrayUnion([1, 2, 3]),
        'previously absent': FieldValue.arrayUnion([1, 2, 3]),
      });

      final snapshot = await doc.get();

      await doc.delete();

      expect(snapshot.data['array'], [1, 2, 3]);
      expect(snapshot.data['empty array in document'], [1, 2, 3]);
      expect(snapshot.data['empty array in argument'], [4, 5]);
      expect(snapshot.data['string and int array'],
          [1, 2, 'three', 'four', 'five', 6]);
      expect(snapshot.data['duplicate elements in document'], [1, 2, 2, 3, 4]);
      expect(snapshot.data['duplicate elements in arguments'], [1, 2, 3, 4, 5]);
      expect(snapshot.data['previously String'], [1, 2, 3]);
      expect(snapshot.data['previously absent'], [1, 2, 3]);
    });

    ftest('FieldValue.arrayRemove', (firestore) async {
      final CollectionReference messages = firestore.collection('messages');

      final DocumentReference doc = messages.document();

      await doc.setData(<String, dynamic>{
        'array': [1, 2],
        'empty array in document': [],
        'empty array in argument': [4, 5],
        'string and int array': [1, 2, 'three', 'four'],
        'duplicate elements in document': [1, 2, 2],
        'duplicate elements in arguments': [1, 2, 3],
        'previously String': 'foo',
      });

      await doc.updateData(<String, dynamic>{
        'array': FieldValue.arrayRemove([1, 3]),
        'empty array in document': FieldValue.arrayRemove([1, 2, 3]),
        'empty array in argument': FieldValue.arrayRemove([]),
        'string and int array': FieldValue.arrayRemove([2, 'five', 'four']),
        'duplicate elements in document': FieldValue.arrayRemove([2, 3, 4]),
        'duplicate elements in arguments': FieldValue.arrayRemove([4, 3, 4, 5]),
        'previously String': FieldValue.arrayRemove([1]),
        'previously absent': FieldValue.arrayRemove([1]),
      });

      final snapshot = await doc.get();

      await doc.delete();

      expect(snapshot.data['array'], [2]);
      expect(snapshot.data['empty array in document'], []);
      expect(snapshot.data['empty array in argument'], [4, 5]);
      expect(snapshot.data['string and int array'], [1, 'three']);
      expect(snapshot.data['duplicate elements in document'], [1]);
      expect(snapshot.data['duplicate elements in arguments'], [1, 2]);
      expect(snapshot.data['previously String'], []);
      expect(snapshot.data['previously absent'], []);
    });
  });
}
