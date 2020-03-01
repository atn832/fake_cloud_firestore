import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

enum MockFieldValue {
  delete,
  serverTimestamp,
}

// Mock implementation of a FieldValue. We store values as a simple string.
// ignore: invalid_use_of_visible_for_testing_member
class MockFieldValuePlatform extends Mock with MockPlatformInterfaceMixin implements FieldValuePlatform {
  final MockFieldValue value;

  MockFieldValuePlatform(this.value);
}
