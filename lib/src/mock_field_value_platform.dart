import 'package:clock/clock.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:fake_cloud_firestore/src/util.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

abstract class FakeFieldValue {
  const FakeFieldValue();

  static const delete = FieldValueDelete();
  static final serverTimestamp = FieldValueServerTimestamp();

  void updateDocument(Map<String, dynamic> document, String key);
}

class FieldValueServerTimestamp extends FakeFieldValue {
  Clock? _clock;

  FieldValueServerTimestamp();

  set clock(Clock clock) {
    _clock = clock;
  }

  Timestamp get now {
    return Timestamp.fromDate(_clock?.now() ?? DateTime.now());
  }

  @override
  void updateDocument(Map<String, dynamic> document, String key) {
    document[key] = now;
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
  final num value;

  const FieldValueIncrement(this.value);

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
  final List<dynamic> elements;

  FieldValueArrayUnion(List<dynamic> _elements)
      : elements = transformValue(_elements, timestampFromDateTime);

  @override
  void updateDocument(Map<String, dynamic> document, String key) {
    final previousValue = document[key];
    // If the field being modified is not already an array it will be
    // overwritten with an array containing exactly the specified elements.
    // https://firebase.google.com/docs/reference/js/firebase.firestore.FieldValue#arrayunion
    final updatedValue = previousValue is List ? List.from(previousValue) : [];
    for (final item in elements) {
      if (!updatedValue.any((element) => deepEqual(element, item))) {
        updatedValue.add(item);
      }
    }
    document[key] = updatedValue;
  }
}

class FieldValueArrayRemove extends FakeFieldValue {
  final List<dynamic> elements;

  FieldValueArrayRemove(List<dynamic> _elements)
      : elements = transformValue(_elements, timestampFromDateTime);

  @override
  void updateDocument(Map<String, dynamic> document, String key) {
    final previousValue = document[key];
    // If the field being modified is not already an array it will be
    // overwritten with an empty array.
    // https://firebase.google.com/docs/reference/js/firebase.firestore.FieldValue#arrayunion
    final updatedValue = previousValue is List ? List.from(previousValue) : [];
    updatedValue.removeWhere(
        (item) => elements.any((element) => deepEqual(element, item)));
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MockFieldValuePlatform &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}
