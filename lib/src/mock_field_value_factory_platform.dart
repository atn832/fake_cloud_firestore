import 'package:cloud_firestore_mocks/src/mock_field_value_platform.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFieldValueFactoryPlatform extends Mock with MockPlatformInterfaceMixin implements FieldValueFactoryPlatform {
  FieldValuePlatform delete() {
    return MockFieldValuePlatform(MockFieldValue.delete);
  }

  FieldValuePlatform serverTimestamp() {
    return MockFieldValuePlatform(MockFieldValue.serverTimestamp);
  }
}
