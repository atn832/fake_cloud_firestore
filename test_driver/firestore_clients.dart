import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

Future<FirebaseFirestore> createFireStoreClient(
    String appName, String? host, bool sslEnabled) async {
  // This is from https://github.com/FirebaseExtended/flutterfire/blob/master/packages/cloud_firestore/cloud_firestore/example/test_driver/cloud_firestore.dart
  final firebaseOptions = const FirebaseOptions(
    appId: '1:79601577497:ios:5f2bcc6ba8cecddd',
    messagingSenderId: '79601577497',
    apiKey: 'AIzaSyArgmRGfB5kiQT6CunAOmKRVKEsxKmy6YI-G72PVU',
    projectId: 'flutter-firestore',
  );
  final app = await Firebase.initializeApp(
    name: appName,
    options: firebaseOptions,
  );
  final firestore = FirebaseFirestore.instanceFor(app: app);
  firestore.settings = Settings(
    persistenceEnabled: true,
    host: host,
    sslEnabled: sslEnabled,
    cacheSizeBytes: 1048576,
  );
  return firestore;
}

// Firestore instances to compare their behavior
Map<String, Future<FirebaseFirestore?>> firestoreFutures = {};

typedef TestCase = Future<void> Function(FirebaseFirestore firestore);

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
