import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final completer = Completer<String>();
  enableFlutterDriverExtension(handler: (_) => completer.future);
  tearDownAll(() => completer.complete(''));

  group('$FirebaseFirestore', () {
    late FirebaseFirestore firestore;
    late FirebaseFirestore firestoreWithSettings;

    setUp(() async {
      final firebaseOptions = const FirebaseOptions(
        appId: '1:79601577497:ios:5f2bcc6ba8cecddd',
        messagingSenderId: '79601577497',
        apiKey: 'AIzaSyArgmRGfB5kiQT6CunAOmKRVKEsxKmy6YI-G72PVU',
        projectId: 'flutter-firestore',
      );
      final app = await Firebase.initializeApp(
        name: 'test',
        options: firebaseOptions,
      );
      final app2 = await Firebase.initializeApp(
        name: 'test2',
        options: firebaseOptions,
      );
      firestore = FirebaseFirestore.instanceFor(app: app);
      firestoreWithSettings = FirebaseFirestore.instanceFor(app: app2);
      firestoreWithSettings.settings = Settings(
        persistenceEnabled: true,
        host: null,
        sslEnabled: true,
        cacheSizeBytes: 1048576,
      );
    });

    test('getDocumentsWithFirebaseFirestoreSettings', () async {
      final query = firestoreWithSettings.collection('messages').limit(1);
      final querySnapshot = await query.get();
      expect(querySnapshot.docs.length, 1);
    });

    test('getDocumentsFromCollection', () async {
      final query = firestore
          .collection('messages')
          .where('message', isEqualTo: 'Hello world!')
          .limit(1);
      final querySnapshot = await query.get();
      expect(querySnapshot.metadata, isNotNull);
      expect(querySnapshot.docs.first.get('message'), 'Hello world!');
      final firstDoc = querySnapshot.docs.first.reference;
      final documentSnapshot = await firstDoc.get();
      expect(documentSnapshot.get('message'), 'Hello world!');
      final cachedSnapshot =
          await firstDoc.get(GetOptions(source: Source.cache));
      expect(cachedSnapshot.get('message'), 'Hello world!');
      final snapshot = await firstDoc.snapshots().first;
      expect(snapshot.get('message'), 'Hello world!');
    });

    test('getDocumentsFromCollectionGroup', () async {
      final query = firestore
          .collectionGroup('reviews')
          .where('stars', isEqualTo: 5)
          .limit(1);
      final querySnapshot = await query.get();
      expect(querySnapshot.docs.first.get('stars'), 5);
      expect(querySnapshot.metadata, isNotNull);
    });

    test('increment', () async {
      final ref = firestore.collection('messages').doc();
      await ref.set(<String, dynamic>{
        'message': 1,
        'created_at': FieldValue.serverTimestamp(),
      });
      var snapshot = await ref.get();
      expect(snapshot.get('message'), 1);
      await ref.update(<String, dynamic>{
        'message': FieldValue.increment(1),
      });
      snapshot = await ref.get();
      expect(snapshot.get('message'), 2);
      await ref.update(<String, dynamic>{
        'message': FieldValue.increment(40.1),
      });
      snapshot = await ref.get();
      expect(snapshot.get('message'), 42.1);

      // Call several times without awaiting the result
      await Future.wait<void>(List<Future<void>>.generate(
        3,
        (int i) => ref.update(<String, dynamic>{
          'message': FieldValue.increment(i),
        }),
      ));
      snapshot = await ref.get();
      expect(snapshot.get('message'), 45.1);
      await ref.delete();
    });

    test('includeMetadataChanges', () async {
      final ref = firestore.collection('messages').doc();
      final snapshotWithoutMetadataChanges =
          ref.snapshots(includeMetadataChanges: false).take(1);
      // It should take either two or three snapshots to make a change when
      // metadata is included, depending on whether `hasPendingWrites` and
      // `isFromCache` update at the same time.
      final snapshotsWithMetadataChanges =
          ref.snapshots(includeMetadataChanges: true).take(3);

      await ref.set(<String, dynamic>{'hello': 'world'});

      var snapshot = await snapshotWithoutMetadataChanges.first;
      expect(snapshot.metadata.hasPendingWrites, true);
      expect(snapshot.metadata.isFromCache, true);
      expect(snapshot.get('hello'), 'world');

      snapshot = await snapshotsWithMetadataChanges.take(1).first;
      expect(snapshot.metadata.hasPendingWrites, true);
      expect(snapshot.metadata.isFromCache, true);
      expect(snapshot.get('hello'), 'world');

      while (
          snapshot.metadata.hasPendingWrites || snapshot.metadata.isFromCache) {
        snapshot = await snapshotsWithMetadataChanges.take(1).first;
      }
      expect(snapshot.get('hello'), 'world');

      await ref.delete();
    });

    test('runTransaction', () async {
      final ref = firestore.collection('messages').doc();
      await ref.set(<String, dynamic>{
        'message': 'testing',
        'created_at': FieldValue.serverTimestamp(),
      });
      final initialSnapshot = await ref.get();
      expect(initialSnapshot.get('message'), 'testing');
      final dynamic result = await firestore.runTransaction(
        (Transaction tx) async {
          final snapshot = await tx.get(ref);
          final updatedData = Map<String, dynamic>.from(snapshot.data()!);
          updatedData['message'] = 'testing2';
          tx.update(ref, updatedData);
          return updatedData;
        },
      );
      expect(result['message'], 'testing2');

      await ref.delete();
      final nonexistentSnapshot = await ref.get();
      expect(nonexistentSnapshot.data, null);
      expect(nonexistentSnapshot.exists, false);
    });

    test('pagination', () async {
      // Populate the database with two test.docs
      final messages = firestore.collection('messages');
      final doc1 = messages.doc();
      // Use document ID as a unique identifier to ensure that we don't
      // collide with other tests running against this database.
      final testRun = doc1.id;
      await doc1.set(<String, dynamic>{
        'message': 'pagination testing1',
        'test_run': testRun,
        'created_at': FieldValue.serverTimestamp(),
      });
      final snapshot1 = await doc1.get();
      final doc2 = messages.doc();
      await doc2.set(<String, dynamic>{
        'message': 'pagination testing2',
        'test_run': testRun,
        'created_at': FieldValue.serverTimestamp(),
      });
      final snapshot2 = await doc2.get();

      QuerySnapshot snapshot;
      List<DocumentSnapshot> results;

      // startAtDocument
      snapshot = await messages
          .orderBy('created_at')
          .where('test_run', isEqualTo: testRun)
          .startAtDocument(snapshot1)
          .get();
      results = snapshot.docs;
      expect(results.length, 2);
      expect(results[0].get('message'), 'pagination testing1');
      expect(results[1].get('message'), 'pagination testing2');

      // startAfterDocument
      snapshot = await messages
          .orderBy('created_at')
          .where('test_run', isEqualTo: testRun)
          .startAfterDocument(snapshot1)
          .get();
      results = snapshot.docs;
      expect(results.length, 1);
      expect(results[0].get('message'), 'pagination testing2');

      // endAtDocument
      snapshot = await messages
          .orderBy('created_at')
          .where('test_run', isEqualTo: testRun)
          .endAtDocument(snapshot2)
          .get();
      results = snapshot.docs;
      expect(results.length, 2);
      expect(results[0].get('message'), 'pagination testing1');
      expect(results[1].get('message'), 'pagination testing2');

      // endBeforeDocument
      snapshot = await messages
          .orderBy('created_at')
          .where('test_run', isEqualTo: testRun)
          .endBeforeDocument(snapshot2)
          .get();
      results = snapshot.docs;
      expect(results.length, 1);
      expect(results[0].get('message'), 'pagination testing1');

      // startAtDocument - endAtDocument
      snapshot = await messages
          .orderBy('created_at')
          .where('test_run', isEqualTo: testRun)
          .startAtDocument(snapshot1)
          .endAtDocument(snapshot2)
          .get();
      results = snapshot.docs;
      expect(results.length, 2);
      expect(results[0].get('message'), 'pagination testing1');
      expect(results[1].get('message'), 'pagination testing2');

      // startAfterDocument - endBeforeDocument
      snapshot = await messages
          .orderBy('created_at')
          .where('test_run', isEqualTo: testRun)
          .startAfterDocument(snapshot1)
          .endBeforeDocument(snapshot2)
          .get();
      results = snapshot.docs;
      expect(results.length, 0);

      // Clean up
      await doc1.delete();
      await doc2.delete();
    });

    test('pagination with map', () async {
      // Populate the database with two test.docs.
      final messages = firestore.collection('messages');
      final doc1 = messages.doc();
      // Use document ID as a unique identifier to ensure that we don't
      // collide with other tests running against this database.
      final testRun = doc1.id;
      await doc1.set(<String, dynamic>{
        'cake': <String, dynamic>{
          'flavor': <String, dynamic>{'type': 1, 'test_run': testRun}
        }
      });

      final snapshot1 = await doc1.get();
      final doc2 = await messages.add(<String, dynamic>{
        'cake': <String, dynamic>{
          'flavor': <String, dynamic>{'type': 2, 'test_run': testRun}
        }
      });

      QuerySnapshot snapshot;
      List<DocumentSnapshot> results;

      // One pagination call is enough as all of the pagination methods use the same method to get data internally.
      snapshot = await messages
          .orderBy('cake.flavor.type')
          .where('cake.flavor.test_run', isEqualTo: testRun)
          .startAtDocument(snapshot1)
          .get();
      results = snapshot.docs;

      expect(results.length, 2);
      expect(results[0].get('cake')['flavor']['type'], 1);
      expect(results[1].get('cake')['flavor']['type'], 2);

      await doc1.delete();
      await doc2.delete();
    });

    test('FieldPath.documentId', () async {
      // Populate the database with two test.docs.
      final messages = firestore.collection('messages');

      // Use document ID as a unique identifier to ensure that we don't
      // collide with other tests running against this database.
      final doc = messages.doc();
      final documentId = doc.id;

      await doc.set(<String, dynamic>{
        'message': 'testing field path',
        'created_at': FieldValue.serverTimestamp(),
      });

      // This tests the native implementations of the where and
      // orderBy methods handling FieldPath.documentId.
      // There is also an error thrown when ordering by document id
      // natively, however, that is also covered by assertion
      // on the Dart side, which is tested with a unit test.
      final querySnapshot = await messages
          .orderBy(FieldPath.documentId)
          .where(FieldPath.documentId, isEqualTo: documentId)
          .get();

      await doc.delete();

      final results = querySnapshot.docs;
      final result = results[0];

      expect(results.length, 1);
      expect(result.get('message'), 'testing field path');
      expect(result.id, documentId);
    });
  });
}
