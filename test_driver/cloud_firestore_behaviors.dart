import 'dart:async';
import 'dart:convert' show utf8;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test/test.dart' as _test;

import 'firestore_clients.dart';

/// Test cases to compare 3 Firestore implementation behaviors: Cloud
/// Firestore backend, Emulator backend, and fake_cloud_firestore.
void main() {
  final completer = Completer<String>();
  enableFlutterDriverExtension(handler: (_) => completer.future);
  tearDownAll(() => completer.complete(''));

  // cloud_firestore backed by Cloud Firestore (project ID: flutter-firestore)
  firestoreFutures = {
    'Cloud Firestore': createFireStoreClient('test', null, true),

    // cloud_firestore backed by Firestore Emulator
    'Firestore Emulator':
        createFireStoreClient('test2', 'localhost:8080', false),

    // fake_cloud_firestore
    'fake_cloud_firestore': Future.value(FakeFirebaseFirestore())
  };

  group('Firestore behavior comparison:', () {
    ftest('Document creation by add', (firestore) async {
      final messages = firestore.collection('messages');

      final doc = await messages.add({
        'message': 'hello firestore',
        'created_at': DateTime
            .now(), // MockFieldValue interferes FieldValue.serverTimestamp
      });
      final documentId = doc.id;
      final result = await doc.get();

      await doc.delete();

      expect(documentId.length, _test.greaterThanOrEqualTo(20));
      final data = result.data();
      expect(data, isNotNull);
      expect(data!['message'], 'hello firestore');
    });

    ftest('Invalidate bad values', (firestore) async {
      final messages = firestore.collection('messages');

      final invalidValues = [
        BigInt.from(3),
        [
          [
            {
              'k': [BigInt.from(3)]
            }
          ]
        ],
      ];

      for (final value in invalidValues) {
        expect(
            () async => await messages.add({
                  'field': value,
                }),
            throwsA(isA<ArgumentError>()),
            reason: 'add should invalidate bad value');

        expect(() async {
          final doc = messages.doc();
          await doc.set({
            'field': value,
          });
        }, throwsA(isA<ArgumentError>()),
            reason: 'setData should invalidate bad value');

        expect(() async {
          final doc = messages.doc();
          await doc.update({
            'foo': value,
          });
        }, throwsA(isA<ArgumentError>()),
            reason: 'updateData should invalidate bad value');
      }
    });

    ftest('Array containing a cycle', (firestore) async {
      final messages = firestore.collection('messages');

      final cyclicArray = <dynamic>[1, 2];
      final object = {
        'foo': [
          3,
          {
            'bar': [4, cyclicArray],
          }
        ],
      };
      cyclicArray.add(object);

      expect(
          () async => await messages.add({
                'array': cyclicArray,
              }),
          // It's a bit surprising but Cloud Firestore throws StackOverflowError
          // upon such nested data.
          throwsA(isA<StackOverflowError>()));
    });

    ftest('Document creation by setData', (firestore) async {
      final messages = firestore.collection('messages');

      final doc = messages.doc();
      final documentId = doc.id;

      final currentDateTime = DateTime.now();
      await doc.set(<String, dynamic>{
        'message': 'hello firestore',
        'created_at': currentDateTime,
        'nested1': {
          'field2': 2,
          'nested2': {
            'field3': 3,
            'nested3': {'field4': 4}
          }
        }
      });

      final result = await doc.get();

      await doc.delete();

      expect(result.id, documentId);
      expect(result.data()!['message'], 'hello firestore');
      final map1 = result.data()!['nested1'];
      expect(map1['field2'], 2);
      final map2 = map1['nested2'];
      expect(map2['field3'], 3);
      final map3 = map2['nested3'];
      expect(map3['field4'], 4);
    });

    ftest('Documents should be saved separately', (firestore) async {
      final messages = firestore.collection('messages');

      final array = [
        0,
        1,
        2,
        {
          'nested1': {
            'nested2': [
              {'nested3': 'value3'}
            ]
          }
        }
      ];
      final map = {
        'k1': 'old value 1',
        'nested1': {
          'nested2': {'k2': 'old value 2'}
        }
      };

      // 1: setData
      final document1 = messages.doc();
      await document1.set(<String, dynamic>{
        'array': array,
        'map': map,
      });

      // 2: addData
      final document2 = await messages.add({
        'array': array,
        'map': map,
      });

      // 3: updateData
      final document3 = messages.doc();
      await document3.set({});
      await document3.update({
        'array': array,
        'map': map,
      });

      // The following modifications have no effect the data in Firestore
      array.add(3);
      final innerArray =
          ((array[3] as Map)['nested1'] as Map)['nested2'] as List;
      (innerArray[0] as Map)['nested3'] = 'unexpected value';
      map['k1'] = 'unexpected value';

      final result1 = await document1.get();
      final result2 = await document2.get();
      final result3 = await document3.get();

      await document1.delete();
      await document2.delete();
      await document3.delete();

      final reasons = ['setData', 'add', 'updateData'];
      final results = [result1, result2, result3];
      for (var i = 0; i < results.length; ++i) {
        final result = results[i];
        final expected = [
          0,
          1,
          2,
          {
            'nested1': {
              'nested2': [
                {'nested3': 'value3'}
              ]
            }
          }
        ];
        expect(result.get('array'), expected,
            reason: 'Array modification should not affect ${reasons[i]}');

        final map1 = result.get('map');
        expect(map1['k1'], 'old value 1',
            reason: 'Map modification should not affect ${reasons[i]}');
        final map2 = map1['nested1'];
        final map3 = map2['nested2'];
        expect(map3['k2'], 'old value 2',
            reason: 'Nested map modification should not affect ${reasons[i]}');
      }
    });

    ftest('Timestamp field', (firestore) async {
      final messages = firestore.collection('messages');
      final doc = messages.doc();

      final currentDateTime = DateTime.now();
      await doc.set(<String, dynamic>{
        'message': 'hello firestore',
        'created_at': currentDateTime,
      });

      final result = await doc.get();

      await doc.delete();

      expect(result.get('created_at'), _test.isA<Timestamp>());
      final data = result.data();
      expect(data, isNotNull);
      final createdAt = (data!['created_at'] as Timestamp).toDate();

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
      final recipients = firestore.collection('messages');

      final doc = recipients.doc();
      final documentId = doc.id;

      final result = await doc.get();

      expect(documentId.length, _test.greaterThanOrEqualTo(20));
      expect(doc.path, 'messages/$documentId');
      expect(result.data, null);
    });

    ftest('Nested objects creation with updateData', (firestore) async {
      final messages = firestore.collection('messages');

      final doc = messages.doc();
      // updateData requires an existing document
      await doc.set({'foo': 'bar'});

      await doc.update({
        'nested.data.message': 'value in nested data',
      });

      final result = await doc.get();

      await doc.delete();

      final nested = result.get('nested');
      final nestedData = nested['data'];
      expect(nestedData['message'], 'value in nested data');
    });

    ftest('Nested objects update', (firestore) async {
      final messages = firestore.collection('messages');

      final doc = messages.doc();
      // updateData requires an existing document
      await doc.set({
        'foo': 'bar',
        'nested': {
          'data': {'message': 'old value1', 'unaffected_field': 'old value2'}
        }
      });

      await doc.update({
        'nested.data.message': 'updated value',
      });
      final result2 = await doc.get();

      await doc.delete();

      final nested2 = result2.get('nested') as Map<dynamic, dynamic>;
      final nestedData2 = nested2['data'] as Map<dynamic, dynamic>;
      expect(nestedData2['message'], 'updated value');
      expect(nestedData2['unaffected_field'], 'old value2');
    });

    ftest('Snapshot should not be affected by updates', (firestore) async {
      final messages = firestore.collection('messages');

      final doc = messages.doc();
      // updateData requires an existing document
      await doc.set({
        'foo': 'old',
        'nested': {
          'data': {'message': 'old nested data'}
        }
      });

      final snapshot = await doc.get();

      await doc.set({'foo': 'new'});
      await doc.update({'nested.data.message': 'new nested data'});

      await doc.delete();

      // At the time the snapshot was created, the value was 'old'
      expect(snapshot.get('foo'), 'old');
      final data = snapshot.data();
      expect(data, isNotNull);
      final nested = data!['nested'];
      final nestedData = nested['data'];
      expect(nestedData['message'], 'old nested data');
    });

    ftest('Transaction: get, set, update, and delete', (firestore) async {
      final foo = firestore.collection('messages').doc('foo');
      final bar = firestore.collection('messages').doc('bar');
      final baz = firestore.collection('messages').doc('baz');
      await foo.set({'name': 'Foo'});
      await bar.set({'name': 'Bar'});
      await baz.set({'name': 'Baz'});

      final result = await firestore.runTransaction((tx) async {
        final snapshotFoo = await tx.get(foo);

        tx.set(foo, {
          'name': snapshotFoo.get('name') + 'o',
        });
        tx.update(bar, {
          'nested.field': 123,
        });
        tx.delete(baz);
        return {'k': 'v'};
      });
      expect(result['k'], 'v');

      final updatedSnapshotFoo = await foo.get();
      expect(updatedSnapshotFoo.get('name'), 'Fooo');

      final updatedSnapshotBar = await bar.get();
      final nestedDocument = updatedSnapshotBar.get('nested');
      expect(nestedDocument['field'], 123);

      final deletedSnapshotBaz = await baz.get();
      expect(deletedSnapshotBaz.exists, false);
    });

    ftest('Transaction handler returning void result', (firestore) async {
      final foo = firestore.collection('messages').doc('foo');
      await foo.set({'name': 'Foo'});

      final result = await firestore.runTransaction((tx) async {
        final snapshotFoo = await tx.get(foo);

        tx.set(foo, {'name': snapshotFoo.data()!['name'] + 'o'});
        // not returning a map
      });
      expect(result, _test.isEmpty);

      final updatedSnapshotFoo = await foo.get();
      expect(updatedSnapshotFoo.get('name'), 'Fooo');
    });

    ftest('Transaction handler returning non-map result', (firestore) async {
      final foo = firestore.collection('messages').doc('foo');
      await foo.set({'name': 'Foo'});

      Future<dynamic> erroneousTransactionUsage() async {
        await firestore.runTransaction((tx) async {
          final snapshotFoo = await tx.get(foo);

          tx.set(foo, {
            'name': snapshotFoo.get('name') + 'oo',
          });
          // Although TransactionHandler's type signature does not specify
          // the return value type, it fails non-map return value.
          return 3;
        });
      }

      expect(erroneousTransactionUsage, _test.throwsA(_test.isA<TypeError>()));
    });

    // In Firestore Transaction, read operations must come before write operations
    // https://firebase.google.com/docs/firestore/manage-data/transactions#transactions
    ftest('Transaction: reads must come before writes', (firestore) async {
      final foo = firestore.collection('messages').doc('foo');
      final bar = firestore.collection('messages').doc('bar');
      await foo.set({'name': 'Foo'});
      await bar.set({'name': 'Bar'});

      Future<dynamic> erroneousTransactionUsage() async {
        await firestore.runTransaction((tx) async {
          final snapshotFoo = await tx.get(foo);

          tx.set(foo, {
            'name': snapshotFoo.get('name') + 'o',
          });
          // get (read operation) cannot come after set
          await tx.get(bar);
        });
      }

      expect(erroneousTransactionUsage,
          _test.throwsA(_test.isA<PlatformException>()));
    });

    ftest('Transaction: result map with invalid types', (firestore) async {
      // It's not documented, but runTransaction fails when certain data types
      // are present in the result map. It seems Cloud Firestore follows this
      // restriction in Firebase HttpsCallableReference, with exception of
      // Timestamp and DateTime:
      // https://firebase.google.com/docs/reference/android/com/google/firebase/functions/HttpsCallableReference#public-taskhttpscallableresult-call-object-data
      final badTypes = <dynamic>[
        firestore.collection('messages').doc('foo'),
        BigInt.from(3),
        [1, 2, BigInt.from(3)],
        {
          'k1': {'k2': BigInt.from(3)}
        },
      ];

      for (final badValue in badTypes) {
        Future<dynamic> erroneousTransactionUsage() async {
          await firestore.runTransaction((tx) async {
            return {'bad': badValue};
          });
        }

        expect(erroneousTransactionUsage,
            _test.throwsA(_test.isA<PlatformException>()),
            reason: 'Value $badValue should be considered bad value');
      }
    });

    ftest('Transaction: result map with valid types', (firestore) async {
      final currentTime = DateTime.now();
      final timestamp = Timestamp.fromDate(currentTime);
      final geoPoint = GeoPoint(40.730610, -73.935242); // New York City
      final result = await firestore.runTransaction((tx) async {
        return <String, dynamic>{
          'null': null,
          'int': 1000000000000000000, // within 64 bits
          'double': 1.23,
          'bool': false,
          'String': 'foo',
          'List': [1, 2, 3],
          'Map': {'foo': 2},
          'DateTime': currentTime,
          'Timestamp': timestamp,
          'GeoPoint': geoPoint,
          'Blob': Blob(Uint8List.fromList(utf8.encode('bytes'))),
        };
      });
      expect(result['null'], null);
      expect(result['int'], 1000000000000000000);
      expect(result['double'], 1.23);
      expect(result['bool'], false);
      expect(result['String'], 'foo');
      expect(result['List'], [1, 2, 3]);
      expect(result['Map'], {'foo': 2});
      // It seems the DateTime is converted to TimeStamp losing precision.
      expect(
          result['DateTime'],
          within(
              from: currentTime,
              distance: 1,
              distanceFunction: (DateTime t1, DateTime t2) =>
                  t1.difference(t2).inMilliseconds));
      expect(result['Timestamp'], timestamp);
      expect(result['GeoPoint'], geoPoint);
      expect(result['Blob'], Blob(Uint8List.fromList(utf8.encode('bytes'))));
    });
  });

  ftest('Where: array-contains', (firestore) async {
    await firestore
        .collection('posts')
        .add({'name': 'Document Missing Queried Field'});
    await firestore
        .collection('posts')
        .add({'name': 'Non-Array Field Type', 'tags': 'interesting'});
    await firestore.collection('posts').add({
      'name': 'Post #1',
      'tags': ['mostrecent', 'interesting'],
    });
    await firestore.collection('posts').add({
      'name': 'Post #2',
      'tags': ['mostrecent'],
    });
    await firestore.collection('posts').add({
      'name': 'Post #3',
      'tags': ['mostrecent'],
    });
    await firestore.collection('posts').add({
      'name': 'Post #4',
      'tags': ['mostrecent', 'interesting'],
    });
    final result = await firestore
        .collection('posts')
        .where('tags', arrayContains: 'interesting')
        .get();
    expect(result.docs.length, equals(2));

    // verify the matching documents were returned
    result.docs.forEach((returnedDocument) {
      expect(returnedDocument.get('tags'), contains('interesting'));
    });
  });

  ftest('orderBy returns documents with null fields first', (instance) async {
    await instance
        .collection('usercourses')
        .add({'completed_at': Timestamp.fromDate(DateTime.now())});
    await instance.collection('usercourses').add({'completed_at': null});

    var query = instance.collection('usercourses').orderBy('completed_at');

    query.snapshots().listen(expectAsync1(
      (event) {
        expect(event.docs.first.get('completed_at'), isNull);
        expect(event.docs[1].get('completed_at'), isNotNull);
        expect(event.docs.length, greaterThan(0));
      },
    ));
  });
}
