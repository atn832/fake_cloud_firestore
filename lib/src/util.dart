import 'package:cloud_firestore/cloud_firestore.dart';

dynamic getSubpath(Map<String, dynamic> root, String path) {
  if (root[path] == null) {
    root[path] = Map<String, dynamic>();
  }
  return root[path];
}

dynamic myEncode(dynamic item) {
  if (item is DateTime) {
    return item.toIso8601String();
  } else if (item is Timestamp) {
    return item.toDate().toIso8601String();
  } else if (item is FieldValue) {
    // ignore: invalid_use_of_visible_for_testing_member
    return item.type.toString();
  }
  return item;
}

bool valueMatchesQuery(dynamic value,
    {dynamic isEqualTo,
    dynamic isLessThan,
    dynamic isLessThanOrEqualTo,
    dynamic isGreaterThan,
    dynamic isGreaterThanOrEqualTo,
    dynamic arrayContains,
    List<dynamic> arrayContainsAny,
    List<dynamic> whereIn,
    bool isNull}) {
  if (isEqualTo != null) {
    return value == isEqualTo;
  } else if (isGreaterThan != null) {
    Comparable fieldValue = value;
    if (isGreaterThan is DateTime) {
      isGreaterThan = Timestamp.fromDate(isGreaterThan);
    }
    return fieldValue.compareTo(isGreaterThan) > 0;
  } else if (isGreaterThanOrEqualTo != null) {
    Comparable fieldValue = value;
    if (isGreaterThanOrEqualTo is DateTime) {
      isGreaterThanOrEqualTo = Timestamp.fromDate(isGreaterThanOrEqualTo);
    }
    return fieldValue.compareTo(isGreaterThanOrEqualTo) >= 0;
  } else if (isLessThan != null) {
    Comparable fieldValue = value;
    if (isLessThan is DateTime) {
      isLessThan = Timestamp.fromDate(isLessThan);
    }
    return fieldValue.compareTo(isLessThan) < 0;
  } else if (isLessThanOrEqualTo != null) {
    Comparable fieldValue = value;
    if (isLessThanOrEqualTo is DateTime) {
      isLessThanOrEqualTo = Timestamp.fromDate(isLessThanOrEqualTo);
    }
    return fieldValue.compareTo(isLessThanOrEqualTo) <= 0;
  }
  throw "Unsupported";
}
