import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test/test.dart' as _test;

import 'firestore_clients.dart';

/// Test cases to compare FieldValue implementation behaviors. This test
/// requires 2 invocations. One for cloud_firestore_mocks and the other for
/// real Firestore and Firestore Emulator backend.
///
/// Background: cloud_firestore_mocks overwrites
/// FieldValueFactoryPlatform.instance to use a customized FieldValueFactory.
/// The instance field updates `static final` _factory of FieldValue class.
/// Because the field cannot be updated within one Dart runtime, we need have
/// two invocations for the same set of assertion against cloud_firestore
/// and cloud_firestore_mocks.
void main() async {
  final Completer<String> firestoreImplementationQuery = Completer<String>();
  final Completer<String> completer = Completer<String>();

  FlutterDriver driver;

  enableFlutterDriverExtension(handler: (message) {
    print('test application received $message');
    if (message == 'mock' || message == 'cloud_firestore') {
      print('updating firestoreImplementationQuery');
      firestoreImplementationQuery.complete(message);
      return Future.value('updated firestoreImplementationQuery');
    } else {
      print('returning completer.future');
      return completer.future;
    }
  });
  tearDownAll(() {
    completer.complete(null);
    driver?.close();
  });

  firestoreFutures = {
    // cloud_firestore_mocks
    'cloud_firestore_mocks': firestoreImplementationQuery.future
        .then((value) => value == 'mock' ? MockFirestoreInstance() : null),
    // cloud_firestore backed by Cloud Firestore (project ID:
    // flutter-firestore)
    'Cloud Firestore': firestoreImplementationQuery.future.then((value) =>
        value == 'cloud_firestore'
            ? createFireStoreClient('test', null, true)
            : null),

    // cloud_firestore backed by Firestore Emulator
    'Firestore Emulator': firestoreImplementationQuery.future.then((value) =>
        value == 'cloud_firestore'
            ? createFireStoreClient('test2', 'localhost:8080', false)
            : null),
  };

  // flutter: test application firestoreImplementation: cloud_firestore
  //[VERBOSE-2:ui_dart_state.cc(157)] Unhandled Exception: Bad state: Can't call group() once tests have begun
  //running.

  group('Firestore behavior on FieldValue:', () {
    /*
    setUpAll(() async {
      print('connecting to FlutterDriver');
      driver = await FlutterDriver.connect();
      print('connected to driver');

    });

    print('waiting for firestoreImplementationQuery');
    print('test application firestoreImplementation: $firestoreImplementation');
*/

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
  });
}
