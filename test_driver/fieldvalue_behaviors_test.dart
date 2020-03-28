import 'dart:io';

//import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_driver/flutter_driver.dart';

import 'fieldvalue_behaviors_parameters.dart';

void main() async {
  String firestoreImplementation =
      Platform.environment['FIRESTORE_IMPLEMENTATION'];
  if (!validImplementationNames.contains(firestoreImplementation)) {
    print('Please set environmental varialbe FIRESTORE_IMPLEMENTATION to'
        ' cloud_firestore or cloud_firestore_mocks');
    throw Exception(
        'Please set environmental varialbe FIRESTORE_IMPLEMENTATION to'
        ' cloud_firestore or cloud_firestore_mocks');
  }

  final FlutterDriver driver = await FlutterDriver.connect();

  await driver.requestData(firestoreImplementation);

  await driver.requestData('waiting_test_completion',
      timeout: const Duration(minutes: 1));
  await driver.close();
}
