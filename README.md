# Fake Cloud Firestore

[![pub package](https://img.shields.io/pub/v/fake_cloud_firestore.svg)](https://pub.dartlang.org/packages/fake_cloud_firestore)

Fakes to write unit tests for Cloud Firestore. Instantiate a
`FakeFirebaseFirestore`, then pass it around your project as if it were a
`FirebaseFirestore`. This Fake acts like Firestore except that will only keep
the data in memory. To help debug, you can use `FakeFirebaseFirestore.dump()` to see what's in the
fake database. This is useful to set up the state of your database, then check that your UI
behaves the way you expect.

This project is made to work together with [firebase_auth_mocks](https://pub.dev/packages/firebase_auth_mocks). If you use them together, you can even test your app with security rules.

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

### Usage in a UI test

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

### With Security Rules

For every [DocumentReference] operation such as get, set, update, [FakeFirebaseFirestore] will check security rules and throw exceptions if access is restricted. Later we will implement security checks for DocumentReference.delete, batch requests, collections and queries. Furthermore, we rely on [Fake Firebase Rules](https://pub.dev/packages/fake_firebase_security_rules), which does not support `timestamps` and `durations` yet.

In the example below, we restrict `users/{userId}` documents to their respective owners. Before they sign in, they cannot access any document inside the `users` collection. Once they sign in, they have access to only their own `users/[uid]` document.

```dart
// https://firebase.google.com/docs/rules/rules-and-auth#leverage_user_information_in_rules
final authUidDescription = '''
service cloud.firestore {
  match /databases/{database}/documents {
    // Make sure the uid of the requesting user matches name of the user
    // document. The wildcard expression {userId} makes the userId variable
    // available in rules.
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}''';

main() async {
  final auth = MockFirebaseAuth();
  final firestore = FakeFirebaseFirestore(
      // Pass security rules to restrict `/users/{user}` documents.
      securityRules: authUidDescription,
      // Make MockFirebaseAuth inform FakeFirebaseFirestore of sign-in
      // changes.
      authObject: auth.authForFakeFirestore);
  // The user signs-in. FakeFirebaseFirestore knows about it thanks to
  // `authObject`.
  await auth.signInWithCustomToken('some token');
  final uid = auth.currentUser!.uid;
  // Now the user can access their user-specific document.
  expect(
      () => firestore.doc('users/$uid').set({'name': 'abc'}), returnsNormally);
  // But not anyone else's.
  expect(() => firestore.doc('users/abcdef').set({'name': 'abc'}),
      throwsException);
}
```

See <https://github.com/atn832/fake_cloud_firestore/blob/master/test/security_test.dart> for more examples of security rules.

## Features

- Dump the state of the fake firebase with `FakeFirebaseFirestore.dump()`.
- Create documents and collections.
- Supports Converters.
- Create documents with `collection.add` or `document.set`.
- Batch writes and `runTransaction`.
- Query documents with `collection.snapshots` or `query.get`.
- Queries:
  - Filter results with `query.where`. The library supports `equals`, `isGreaterThan`, `isGreaterThanOrEqualTo`, `isLessThan`,`isLessThanOrEqualTo`, `isNull`, `isNotEqualTo`, `arrayContains`, `arrayContainsAny`, `whereIn` and `whereNotIn`.
  - Sort results with `query.orderBy`.
  - Limit results with `query.limit`, `limitToLast`, `startAfterDocument`, `startAt`, `startAtDocument`, `endAt`, `endAtDocument`, `endBefore`, `endBeforeDocument`. Note: `startAnd` and `endAt` work only on exact matches.
  - Aggregate with `query.count`.
- `ValueField`:
  - set timestamps with `FieldValue.serverTimestamp()`.
  - delete values with `FieldValue.delete()`.
  - update numerical values with `FieldValue.increment`.
  - update arrays with `FieldValue.arrayUnion` and `FieldValue.arrayRemove`.
- Mock exceptions for `DocumentReference.set`.
- Security rules:
  - Initialize `FakeFirebaseFirestore` with custom security rules.
  - `FakeFirebaseFirestore` takes authentication state from firebase_auth_mocks into account.
  - `Document.get`, `set`, and `update` are protected.

## Compatibility table

| cloud_firestore | fake_cloud_firestore  |
|-----------------|-----------------------|
| 4.0.0           | 2.0.0                 |
| 3.4.0           | 1.3.0                 |
| 3.0.0           | 1.2.1                 |
| 2.2.0           | 1.1.0                 |
| 2.1.0           | 1.0.2                 |
| 1.0.0           | 0.8.4                 |
| 0.16.0          | 0.6.0                 |
| 0.14.0          | 0.5.0                 |
| 0.13.1+1        | 0.4.1                 |
| 0.13.0+1        | 0.2.5                 |
| ^0.12.9+6       | 0.2.0                 |

## Features and bugs

Please file feature requests and bugs at the issue tracker.
