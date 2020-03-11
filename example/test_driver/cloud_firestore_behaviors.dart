import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test/test.dart' as _test;

Future<Firestore> createFireStoreClient(
    String appName, String host, bool sslEnabled) async {
  // This is from https://github.com/FirebaseExtended/flutterfire/blob/master/packages/cloud_firestore/cloud_firestore/example/test_driver/cloud_firestore.dart
  final FirebaseOptions firebaseOptions = const FirebaseOptions(
    googleAppID: '1:79601577497:ios:5f2bcc6ba8cecddd',
    gcmSenderID: '79601577497',
    apiKey: 'AIzaSyArgmRGfB5kiQT6CunAOmKRVKEsxKmy6YI-G72PVU',
    projectID: 'flutter-firestore',
  );
  final FirebaseApp app = await FirebaseApp.configure(
    name: appName,
    options: firebaseOptions,
  );
  final firestore = Firestore(app: app);
  await firestore.settings(
    persistenceEnabled: true,
    host: host,
    sslEnabled: sslEnabled,
    cacheSizeBytes: 1048576,
  );
  return firestore;
}

// 3 Firestore instances to compare their behavior
Map<String, Future<Firestore>> firestoreFutures = {
  // cloud_firestore backed by Cloud Firestore (project ID: flutter-firestore)
  'Cloud Firestore': createFireStoreClient('test', null, true),

  // cloud_firestore backed by Firestore Emulator
  'Firestore Emulator': createFireStoreClient('test2', 'localhost:8080', false),

  // cloud_firestore_mocks
  'cloud_firestore_mocks': Future.value(MockFirestoreInstance())
};

typedef Future<void> TestCase(Firestore firestore);

/// Test case for Firestore instance
void ftest(String testName, TestCase testCase) {
  firestoreFutures.forEach((firestoreName, firestoreFuture) {
    test('$testName ($firestoreName)', () async {
      final firestore = await firestoreFuture;
      await testCase(firestore);
    });
  });
}

/// Test cases to compare 3 Firestore implementation behaviors: Cloud
/// Firestore backend, Emulator backend, and cloud_firestore_mocks.
void main() {
  final Completer<String> completer = Completer<String>();
  enableFlutterDriverExtension(handler: (_) => completer.future);
  tearDownAll(() => completer.complete(null));

  group('Firestore behavior comparison:', () {
    ftest('Document creation by add', (firestore) async {
      final CollectionReference messages = firestore.collection('messages');

      final doc = await messages.add({
        'message': 'hello firestore',
        'created_at': DateTime
            .now(), // MockFieldValue interferes FieldValue.serverTimestamp
      });
      final String documentId = doc.documentID;
      final result = await doc.get();

      await doc.delete();

      expect(documentId.length, _test.greaterThanOrEqualTo(20));
      expect(result.data['message'], 'hello firestore');
    });

    ftest('Document creation by setData', (firestore) async {
      final CollectionReference messages = firestore.collection('messages');

      final DocumentReference doc = messages.document();
      final String documentId = doc.documentID;

      final currentDateTime = DateTime.now();
      await doc.setData(<String, dynamic>{
        'message': 'hello firestore',
        'created_at': currentDateTime,
      });

      final result = await doc.get();

      await doc.delete();

      expect(result.data['message'], 'hello firestore');
      expect(result.documentID, documentId);
    });

    ftest('Timestamp field', (firestore) async {
      final CollectionReference messages = firestore.collection('messages');
      final DocumentReference doc = messages.document();

      final currentDateTime = DateTime.now();
      await doc.setData(<String, dynamic>{
        'message': 'hello firestore',
        'created_at': currentDateTime,
      });

      final result = await doc.get();

      await doc.delete();

      expect(result.data['created_at'], _test.isA<Timestamp>());
      final createdAt = (result.data['created_at'] as Timestamp).toDate();

      // The conversion between Dart's DateTime and Firestore's Timestamp is not a
      // loss-less conversion. For example, asserting createdAt equals to currentDateTime
      // would fail:
      //   Expected: DateTime:<2020-03-10 19:45:26.610680>
      //   Actual: DateTime:<2020-03-10 19:45:26.609999>
      final timeDiff = createdAt.difference(currentDateTime);
      // The difference should be 1 millisecond.
      expect(timeDiff.inMilliseconds, _test.lessThanOrEqualTo(1));
    });

    ftest('Unsaved documens', (firestore) async {
      final CollectionReference recipients = firestore.collection('messages');

      final DocumentReference doc = recipients.document();
      final String documentId = doc.documentID;

      final result = await doc.get();

      expect(documentId.length, _test.greaterThanOrEqualTo(20));
      expect(doc.path, 'messages/$documentId');
      expect(result.data, null);
    });

    ftest('Nested objects creation with updateData', (firestore) async {
      final CollectionReference messages = firestore.collection('messages');

      final DocumentReference doc = messages.document();
      // updateData requires an existing document
      await doc.setData({'foo': 'bar'});

      await doc.updateData(<String, dynamic>{
        'nested.data.message': 'value in nested data',
      });

      // await doc.delete();
      final result = await doc.get();

      await doc.delete();

      final nested = result.data['nested'] as Map<String, dynamic>;
      final nestedData = nested['data'] as Map<String, dynamic>;
      expect(nestedData['message'], 'value in nested data');
    });

    ftest('Nested objects update', (firestore) async {
      final CollectionReference messages = firestore.collection('messages');

      final DocumentReference doc = messages.document();
      // updateData requires an existing document
      await doc.setData({'foo': 'bar'});

      await doc.updateData(<String, dynamic>{
        'nested.data.message': 'old value1',
        'nested.data.unaffected_field': 'old value2',
      });

      await doc.updateData(<String, dynamic>{
        'nested.data.message': 'updated value',
      });
      final result2 = await doc.get();

      await doc.delete();

      final nested2 = result2.data['nested'] as Map<dynamic, dynamic>;
      final nestedData2 = nested2['data'] as Map<dynamic, dynamic>;
      expect(nestedData2['message'], 'updated value');
      expect(nestedData2['unaffected_field'], 'old value2');
    });
  });
}
