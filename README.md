# Cloud Firestore Mocks
[![pub package](https://img.shields.io/pub/v/cloud_firestore_mocks.svg)](https://pub.dartlang.org/packages/cloud_firestore_mocks)

Fakes to write unit tests for Cloud Firestore. Instantiate a
`MockFirestoreInstance`, then pass it around your project as if it were a
`FirestoreInstance`. This fake acts like Firestore except it will only keep
the state in memory.
To help debug, you can use `MockFirestoreInstance.dump()` to see what's in the
fake database.
This is useful to set up the state of your database, then check that your UI
behaves the way you expect.

## Usage

### A simple usage example

```dart
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';

void main() {
  final instance = MockFirestoreInstance();
  await instance.collection('users').add({
    'username': 'Bob',
  });
  final snapshot = await instance.collection('users').get();
  print(snapshot.docs.length); // 1
  print(snapshot.docs.first.get('username')); // 'Bob'
  print(instance.dump());
}

// Prints out:
// {
//   "users": {
//     "z": {
//       "name": "Bob"
//     }
//   }
// }
```

See more examples at [cloud_firestore_mocks/test/cloud_firestore_mocks_test.dart](https://github.com/atn832/cloud_firestore_mocks/blob/master/test/cloud_firestore_mocks_test.dart).

### Usage in a UI test:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';
import 'package:firestore_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const MessagesCollection = 'messages';

void main() {
  testWidgets('shows messages', (WidgetTester tester) async {
    // Populate the mock database.
    final firestore = MockFirestoreInstance();
    await firestore.collection(MessagesCollection).add({
      'message': 'Hello world!',
      'created_at': FieldValue.serverTimestamp(),
    });

    // Render the widget.
    await tester.pumpWidget(MaterialApp(
        title: 'Firestore Example', home: MyHomePage(firestore: firestore)));
    // Let the snapshots stream fire a snapshot.
    await tester.idle();
    // Re-render.
    await tester.pump();
    // // Verify the output.
    expect(find.text('Hello world!'), findsOneWidget);
    expect(find.text('Message 1 of 1'), findsOneWidget);
  });
}
```

See more examples at [cloud_firestore_mocks/example/test/widget_test.dart](https://github.com/atn832/cloud_firestore_mocks/blob/master/example/test/widget_test.dart).

## Features

- Dump the state of the mock firebase with `MockFirestoreInstance.dump()`.
- Create documents and collections.
- Create documents with `collection.add` or `document.set`.
- Batch writes and `runTransaction`.
- Query documents with `collection.snapshots` or `query.get`.
- Queries:
  - Filter results with `query.where`. The library supports `equals`, `isGreaterThan`, `isGreaterThanOrEqualTo`, `isLessThan`,`isLessThanOrEqualTo`, `isNull`, `isNotEqualTo`, `arrayContains`, `arrayContainsAny` and `whereIn`.
  - Sort results with `query.orderBy`.
  - Limit results with `query.limit`, `limitToLast`, `startAfterDocument`, `startAt`, `endAt`. Note: `startAnd` and `endAt` work only on exact matches.
- `ValueField`:
  - set timestamps with `FieldValue.serverTimestamp()`.
  - delete values with `FieldValue.delete()`.
  - update numerical values with `FieldValue.increment`.
  - update arrays with `FieldValue.arrayUnion` and `FieldValue.arrayRemove`.

## Features and bugs

Please file feature requests and bugs at the issue tracker.
