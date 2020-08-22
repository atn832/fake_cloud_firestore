import 'package:cloud_firestore/cloud_firestore.dart';

dynamic getSubpath(Map<String, dynamic> root, String path) {
  return _getSubpath(root, path.split('/'));
}

dynamic _getSubpath(Map<String, dynamic> node, List<String> pathSegments) {
  final firstSegment = pathSegments.first;
  if (node[firstSegment] == null) {
    node[firstSegment] = <String, dynamic>{};
  }
  if (pathSegments.length == 1) {
    return node[firstSegment];
  } else {
    return _getSubpath(node[firstSegment], pathSegments.sublist(1));
  }
}

Map<String, dynamic> buildTreeIncludingCollectionId(
    Map<String, dynamic> root, Map<String, dynamic> node, String collectionId, Map<String, dynamic> result,
    [String path = '']) {
  final pathSegments = path.isEmpty ? [collectionId] : path.split('/');
  for (final entry in node.entries) {
    if (pathSegments.isNotEmpty && pathSegments[pathSegments.length - 1] == collectionId) {
      result[pathSegments.first] = root[pathSegments.first];
    }
    if (entry.value is Map<String, dynamic>) {
      buildTreeIncludingCollectionId(
        root,
        entry.value,
        collectionId,
        result,
        path.isEmpty ? entry.key : '$path/${entry.key}',
      );
    }
  }
  return result;
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

/// Returns copy of data by replicating its inner Maps and Lists.
dynamic deepCopy(dynamic fromData) {
  if (fromData is Map<String, dynamic>) {
    final toMap = Map<String, dynamic>.from(fromData);
    toMap.forEach((key, value) {
      toMap[key] = deepCopy(value);
    });
    return toMap;
  } else if (fromData is List) {
    return fromData.map(deepCopy).toList();
  } else {
    return fromData;
  }
}

/// Throws ArgumentError when the value is not a Cloud Firestore's supported
/// data types.
/// https://firebase.google.com/docs/firestore/manage-data/data-types
void validateDocumentValue(dynamic value) {
  if (value is bool || // Boolean
      value is Blob || // Bytes
      value is DateTime ||
      value is Timestamp ||
      value is double || // Floating-point number
      value is GeoPoint || // Geographical point
      value is int ||
      value == null ||
      value is DocumentReference ||
      value is String ||
      value is FieldValue) {
    // supported data types
    return;
  } else if (value is List) {
    for (final element in value) {
      validateDocumentValue(element);
    }
    return;
  } else if (value is Map<String, dynamic>) {
    for (final element in value.values) {
      validateDocumentValue(element);
    }
    return;
  }
  throw ArgumentError.value(value);
}
