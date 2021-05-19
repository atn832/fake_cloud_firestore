# Fake Cloud Firestore
[![pub package](https://img.shields.io/pub/v/fake_cloud_firestore.svg)](https://pub.dartlang.org/packages/fake_cloud_firestore)

Fakes to write unit tests for Cloud Firestore. Instantiate a
`FakeFirebaseFirestore`, then pass it around your project as if it were a
`FirebaseFirestore`. This fake acts like Firestore except it will only keep
the state in memory.
To help debug, you can use `FakeFirebaseFirestore.dump()` to see what's in the
fake database.
This is useful to set up the state of your database, then check that your UI
behaves the way you expect.

## Usage

### A simple usage example

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  final instance = FakeFirebaseFirestore();
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

See more examples at [fake_cloud_firestore/test/fake_cloud_firestore_test.dart](https://github.com/atn832/fake_cloud_firestore/blob/master/test/fake_cloud_firestore_test.dart).

### Usage in a UI test:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firestore_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const MessagesCollection = 'messages';

void main() {
  testWidgets('shows messages', (WidgetTester tester) async {
    // Populate the fake database.
    final firestore = FakeFirebaseFirestore();
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

See more examples at [fake_cloud_firestore/example/test/widget_test.dart](https://github.com/atn832/fake_cloud_firestore/blob/master/example/test/widget_test.dart).

## Features

- Dump the state of the fake firebase with `FakeFirebaseFirestore.dump()`.
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

## Compatibility table

| cloud_firestore | fake_cloud_firestore |
|-----------------|-----------------------|
| 2.1.0           | 0.9.0                 |
| 1.0.0           | 0.7.0                 |
| 0.16.0          | 0.6.0                 |
| 0.14.0          | 0.5.0                 |
| 0.13.1+1        | 0.4.1                 |
| 0.13.0+1        | 0.2.5                 |
| ^0.12.9+6       | 0.2.0                 |

## Features and bugs

Please file feature requests and bugs at the issue tracker.
