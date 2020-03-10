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

/// Test case to compare 3 Firestore implementation behaviors: Cloud
/// Firestore backend, Emulator backend, and cloud_firestore_mocks.
void main() {
  final Completer<String> completer = Completer<String>();
  enableFlutterDriverExtension(handler: (_) => completer.future);
  tearDownAll(() => completer.complete(null));

  group('Firestore behavior comparison:', () {
    Map<String, Future<Firestore>> firestoreFutures = {
      'Cloud Firestore': createFireStoreClient('test', null, true),
      'Firestore Emulator':
          createFireStoreClient('test2', 'localhost:8080', false),
      'cloud_firestore_mocks': Future.value(MockFirestoreInstance())
    };

    firestoreFutures.forEach((name, firestoreFuture) {
      test('FieldPath.documentId ($name)', () async {
        final firestore = await firestoreFuture;

        // Populate the database with one test documents.
        final CollectionReference messages = firestore.collection('messages');

        // Use document ID as a unique identifier to ensure that we don't
        // collide with other tests running against this database.
        final DocumentReference doc = messages.document();
        final String documentId = doc.documentID;

        await doc.setData(<String, dynamic>{
          'message': 'testing field path',
          'created_at': DateTime.now(), // MockFieldValue causes problem
        });

        final result = await doc.get();

        await doc.delete();

        expect(result.data['message'], 'testing field path');
        expect(result.data['created_at'], _test.isA<Timestamp>());
        expect(result.documentID, documentId);
      });
    });

    firestoreFutures.forEach((name, firestoreFuture) {
      test('Unsaved documens ($name)', () async {
        final firestore = await firestoreFuture;

        final CollectionReference recipients = firestore.collection('messages');

        final DocumentReference doc = recipients.document();
        final String documentId = doc.documentID;

        expect(documentId.length >= 20, true);

        final result = await doc.get();
        expect(doc.path, 'messages/$documentId');
        expect(result.data, null);
      });
    });
  });
}
