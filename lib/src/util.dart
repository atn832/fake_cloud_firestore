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
    return item.toString();
  }
  return item;
}
