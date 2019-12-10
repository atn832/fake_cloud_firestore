Mocks for Cloud Firestore. Use this package to write unit tests involving Cloud Firestore.

## Usage

A simple usage example:

```dart
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';

const uid = 'abc';

void main() {
  final instance = MockFirestoreInstance();
  await instance.collection('users').document(uid).setData({
    'name': 'Bob',
  });
  print(instance.dump());
}

// Prints out:
// {
//   "users": {
//     "abc": {
//       "name": "Bob"
//     }
//   }
// }
```

See more examples at [cloud_firestore_mocks/test/cloud_firestore_mocks_test.dart](https://github.com/atn832/cloud_firestore_mocks/blob/master/test/cloud_firestore_mocks_test.dart).

## Features

- Dump the state of the mock firebase with `MockFirestoreInstance.dump()`.
- Create documents and collections.
- Create documents with `collection.add` or `document.setData`.
- Query documents with `collection.snapshots`, `collection.getDocuments` or `query.getDocuments`.
- Filter results with `where` and `equals`, `isGreaterThan`, `isGreaterThanOrEqualTo`, `isLessThan`, or `isLessThanOrEqualTo`.
- Order results with `orderBy`.
- Limit results with `limit`.

## Features and bugs

Please file feature requests and bugs at the issue tracker.