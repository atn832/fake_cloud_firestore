import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Firestore> createFireStoreClient(
    String appName, String host, bool sslEnabled) async {
  // This is from https://github.com/FirebaseExtended/flutterfire/blob/master/packages/cloud_firestore/cloud_firestore/example/test_driver/cloud_firestore.dart
  final firebaseOptions = const FirebaseOptions(
    googleAppID: '1:79601577497:ios:5f2bcc6ba8cecddd',
    gcmSenderID: '79601577497',
    apiKey: 'AIzaSyArgmRGfB5kiQT6CunAOmKRVKEsxKmy6YI-G72PVU',
    projectID: 'flutter-firestore',
  );
  final app = await FirebaseApp.configure(
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

// Firestore instances to compare their behavior
Map<String, Future<Firestore>> firestoreFutures = {};

typedef TestCase = Future<void> Function(Firestore firestore);

void ftest(String testName, TestCase testCase) {
  if (firestoreFutures.isEmpty) {
    fail('Firestore instances were not initialized correctly');
  }

  firestoreFutures.forEach((firestoreName, firestoreFuture) {
    test('$testName ($firestoreName)', () async {
      final firestore = await firestoreFuture;
      if (firestore != null) {
        await testCase(firestore);
      } else {
        print('Skipping $firestoreName');
      }
    });
  });
}
