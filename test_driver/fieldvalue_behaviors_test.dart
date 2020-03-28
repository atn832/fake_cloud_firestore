import 'dart:io';

//import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_driver/flutter_driver.dart';

void main() async {
  String firestoreImplementation =
      Platform.environment['FIRESTORE_IMPLEMENTATION'] ?? 'mock';
  print('firestoreImplementation in driver: $firestoreImplementation');

  final FlutterDriver driver = await FlutterDriver.connect();

  final response = await driver.requestData(firestoreImplementation);
  print('Driver received $response');

  await driver.requestData(null, timeout: const Duration(minutes: 1));
  await driver.close();
}
