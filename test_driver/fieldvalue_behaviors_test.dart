import 'dart:io';

//import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_driver/flutter_driver.dart';

void main() async {
  String firestoreImplementation =
      Platform.environment['FIRESTORE_IMPLEMENTATION'] ??
          'cloud_firestore_mocks';
  if (firestoreImplementation == null) {
    throw Exception(
        'Please set environmental varialbe FIRESTORE_IMPLEMENTATION to'
        ' cloud_firestore or cloud_firestore_mocks');
  }

  final FlutterDriver driver = await FlutterDriver.connect();

  await driver.requestData(firestoreImplementation);

  await driver.requestData(null, timeout: const Duration(minutes: 1));
  await driver.close();
}
