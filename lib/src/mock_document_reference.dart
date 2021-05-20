import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';

import 'converter.dart';
import 'mock_document_reference_platform.dart';
import 'fake_cloud_firestore_instance.dart';
import 'mock_collection_reference.dart';
import 'mock_document_snapshot.dart';
import 'mock_field_value_platform.dart';
import 'mock_query.dart';
import 'util.dart';

const snapshotsStreamKey = '_snapshots';

class MockDocumentReference<T extends Object?> implements DocumentReference<T> {
  final String _id;
  final Map<String, dynamic> root;
  final Map<String, dynamic> docsData;
  final Map<String, dynamic> rootParent;
  final Map<String, dynamic> snapshotStreamControllerRoot;
  final FakeFirebaseFirestore _firestore;
  final Converter<T>? _converter;

  /// Path from the root to this document. For example "users/USER0004/friends/FRIEND001"
  final String _path;

  StreamController<DocumentSnapshot<T>> get snapshotStreamController {
    if (!snapshotStreamControllerRoot.containsKey(snapshotsStreamKey)) {
      snapshotStreamControllerRoot[snapshotsStreamKey] =
          StreamController<DocumentSnapshot<T>>.broadcast();
    }
    return snapshotStreamControllerRoot[snapshotsStreamKey];
  }

  MockDocumentReference(
      this._firestore,
      this._path,
      this._id,
      this.root,
      this.docsData,
      this.rootParent,
      this.snapshotStreamControllerRoot,
      this._converter);

  // ignore: unused_field
  final DocumentReferencePlatform _delegate = MockDocumentReferencePlatform();

  @override
  FirebaseFirestore get firestore => _firestore;

  @override
  String get id => _id;

  @override
  String get path => _path;

  @override
  CollectionReference<T> get parent {
    final segments = _path.split('/');
    // For any document reference, segment length is more than 1
    final segmentLength = segments.length;
    final parentSegments = segments.sublist(0, segmentLength - 1);
    final parentPath = parentSegments.join('/');
    final parentCollection = _firestore.collection(parentPath);
    if (parentCollection is! CollectionReference<T>) {
      throw UnimplementedError();
    }
    // The compiler still requires a cast, despite
    // https://dart.dev/null-safety/understanding-null-safety#reachability-analysis.
    // Without a cast, the compiler throws this error:
    // > A value of type 'CollectionReference<Map<String, dynamic>>' can't be
    // > returned from the function 'parent' because it has a return type of
    // > 'CollectionReference<T>'.
    // Just like FirebaseFirestore.collection, MockFirestoreInstance returns a
    // CollectionReference<Map<String, dynamic>>. See
    // https://pub.dev/documentation/cloud_firestore/2.1.0/cloud_firestore/FirebaseFirestore/collection.html.
    return parentCollection as CollectionReference<T>;
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    final path = [_path, collectionPath].join('/');
    return MockCollectionReference(
        _firestore,
        path,
        getSubpath(root, collectionPath),
        docsData,
        getSubpath(snapshotStreamControllerRoot, collectionPath));
  }

  @override
  Future<void> update(Map<String, dynamic> data) {
    validateDocumentValue(data);
    // Copy data so that subsequent change to `data` should not affect the data
    // stored in mock document.
    final copy = deepCopy(data);
    copy.forEach((key, value) {
      // document == root if key is not a composite key
      final document = _findNestedDocumentToUpdate(key);
      if (document != docsData[_path]) {
        // Example, key: 'foo.bar.username', get 'username' field
        key = key.split('.').last;
      }
      _applyValues(document, key, value);
    });
    _firestore.saveDocument(path);
    QuerySnapshotStreamManager().fireSnapshotUpdate(path);
    fireSnapshotUpdate();
    return Future.value(null);
  }

  void _applyValues(Map<String, dynamic> document, String key, dynamic value) {
    // Handle the recursive case.
    if (value is Map<String, dynamic>) {
      if (!document.containsKey(key)) {
        document[key] = <String, dynamic>{};
      }
      value.forEach((subkey, subvalue) {
        _applyValues(document[key], subkey, subvalue);
      });
      return;
    }
    // TODO: support handling values in lists.

    // Handle values.
    if (value is FieldValue) {
      final valueDelegate = FieldValuePlatform.getDelegate(value);
      final fieldValuePlatform = valueDelegate as MockFieldValuePlatform;
      final fieldValue = fieldValuePlatform.value;
      fieldValue.updateDocument(document, key);
    } else if (value is DateTime) {
      document[key] = Timestamp.fromDate(value);
    } else {
      document[key] = value;
    }
  }

  Map<String, dynamic> _findNestedDocumentToUpdate(String key) {
    final compositeKeyElements = key.split('.');
    if (!docsData.containsKey(_path)) {
      docsData[_path] = <String, dynamic>{};
    }
    if (compositeKeyElements.length == 1) {
      // This is not a composite key
      return docsData[_path];
    }

    var document = docsData[_path];

    // For N elements, iterate until N-1 element.
    // For example, key: "foo.bar.baz", this method return the document pointed by
    // 'foo.bar'. The document will be updated by the caller on 'baz' field
    final keysToIterate =
        compositeKeyElements.sublist(0, compositeKeyElements.length - 1);
    for (final keyElement in keysToIterate) {
      if (!document.containsKey(keyElement) || !(document[keyElement] is Map)) {
        document[keyElement] = <String, dynamic>{};
        document = document[keyElement];
      } else {
        document = document[keyElement] as Map<String, dynamic>;
      }
    }
    return document;
  }

  @override
  Future<void> set(T data, [SetOptions? options]) {
    final merge = options?.merge ?? false;
    if (!merge && docsData.containsKey(_path)) {
      docsData[_path].clear();
    }
    Map<String, dynamic> rawData;
    if (_converter == null) {
      assert(data is Map<String, dynamic>);
      rawData = data as Map<String, dynamic>;
    } else {
      rawData = _converter!.toFirestore(data, null);
    }
    return update(rawData);
  }

  @override
  Future<DocumentSnapshot<T>> get([GetOptions? options]) {
    // If there is no converter, T is Map<String, dynamic>, so `this` is a
    // DocumentReference<Map,String, dynamic>. If there is a converter, create a
    // rawDocumentReference manually.
    final rawDocumentReference = _converter == null
        ? this as DocumentReference<Map<String, dynamic>>
        : MockDocumentReference<Map<String, dynamic>>(_firestore, _path, _id,
            root, docsData, rootParent, snapshotStreamControllerRoot, null);
    final rawSnapshot = MockDocumentSnapshot<Map<String, dynamic>>(
        rawDocumentReference, _id, docsData[_path], null, false, _exists());
    if (_converter == null) {
      // Since there is no converter, we know that T is Map<String, dynamic>, so
      // it is safe to cast.
      return Future.value(rawSnapshot as DocumentSnapshot<T>);
    }
    // Convert the document.
    final convertedData = _converter!.fromFirestore(rawSnapshot, null);
    final convertedSnapshot = MockDocumentSnapshot<T>(
        this, _id, docsData[_path], convertedData, true, _exists());
    return Future.value(convertedSnapshot);
  }

  bool _exists() {
    return _firestore.hasSavedDocument(_path);
  }

  @override
  Future<void> delete() {
    rootParent.remove(id);
    _firestore.removeSavedDocument(path);
    QuerySnapshotStreamManager().fireSnapshotUpdate(path);
    fireSnapshotUpdate();
    return Future.value();
  }

  @override
  Stream<DocumentSnapshot<T>> snapshots({bool includeMetadataChanges = false}) {
    Future(() {
      fireSnapshotUpdate();
    });

    return snapshotStreamController.stream;
  }

  Future<void> fireSnapshotUpdate() async {
    snapshotStreamController.add(await get());
  }

  @override
  bool operator ==(dynamic o) =>
      o is DocumentReference && o.firestore == _firestore && o.path == _path;

  @override
  int get hashCode => _path.hashCode + _firestore.hashCode;

  @override
  DocumentReference<R> withConverter<R>(
      {required fromFirestore, required toFirestore}) {
    return MockDocumentReference<R>(
        _firestore,
        _path,
        _id,
        root,
        docsData,
        rootParent,
        snapshotStreamControllerRoot,
        Converter(fromFirestore, toFirestore));
  }
}
