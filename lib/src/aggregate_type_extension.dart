import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';

extension AggregateTypeExtension on AggregateType {
  Type get aggregateFieldType {
    switch (this) {
      case AggregateType.sum:
        return sum;
      case AggregateType.average:
        return average;
      case AggregateType.count:
        return count;
    }
  }
}
