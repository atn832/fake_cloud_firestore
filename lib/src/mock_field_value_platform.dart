import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

abstract class FakeFieldValue {
  const FakeFieldValue();
  static const delete = FieldValueDelete();
  static const serverTimestamp = FieldValueServerTimestamp();

  void updateDocument(Map<String, dynamic> document, String key);
}

class FieldValueServerTimestamp extends FakeFieldValue {
  const FieldValueServerTimestamp();

  @override
  void updateDocument(Map<String, dynamic> document, String key) {
    document[key] = Timestamp.now();
  }
}

class FieldValueDelete extends FakeFieldValue {
  const FieldValueDelete();

  @override
  void updateDocument(Map<String, dynamic> document, String key) {
    document.remove(key);
  }
}

class FieldValueIncrement extends FakeFieldValue {
  const FieldValueIncrement(this.value);
  final num value;

  @override
  void updateDocument(Map<String, dynamic> document, String key) {
    final previousValue = document[key];
    // If the field is not present or not a number, then FieldValue.increment
    // sets it as the value.
    // https://firebase.google.com/docs/reference/js/firebase.firestore.FieldValue
    final previousNumber = previousValue is num ? previousValue : 0;
    final updatedValue = previousNumber + value;
    document[key] = updatedValue;
  }
}

class FieldValueArrayUnion extends FakeFieldValue {
  const FieldValueArrayUnion(this.elements);
  final List<dynamic> elements;

  @override
  void updateDocument(Map<String, dynamic> document, String key) {
    final previousValue = document[key];
    // If the field being modified is not already an array it will be
    // overwritten with an array containing exactly the specified elements.
    // https://firebase.google.com/docs/reference/js/firebase.firestore.FieldValue#arrayunion
    final updatedValue = previousValue is List ? List.from(previousValue) : [];
    for (final item in elements) {
      if (!updatedValue.contains(item)) {
        updatedValue.add(item);
      }
    }
    document[key] = updatedValue;
  }
}

class FieldValueArrayRemove extends FakeFieldValue {
  const FieldValueArrayRemove(this.elements);
  final List<dynamic> elements;

  @override
  void updateDocument(Map<String, dynamic> document, String key) {
    final previousValue = document[key];
    // If the field being modified is not already an array it will be
    // overwritten with an empty array.
    // https://firebase.google.com/docs/reference/js/firebase.firestore.FieldValue#arrayunion
    final updatedValue = previousValue is List ? List.from(previousValue) : [];
    updatedValue.removeWhere((item) => elements.contains(item));
    document[key] = updatedValue;
  }
}

// Mock implementation of a FieldValue. We store values as a simple string.
class MockFieldValuePlatform
    with
        // ignore: invalid_use_of_visible_for_testing_member
        MockPlatformInterfaceMixin
    implements
        FieldValuePlatform {
  final FakeFieldValue value;

  MockFieldValuePlatform(this.value);
}
