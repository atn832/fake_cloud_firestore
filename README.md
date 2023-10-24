# Fake Cloud Firestore

[![pub package](https://img.shields.io/pub/v/fake_cloud_firestore.svg)](https://pub.dartlang.org/packages/fake_cloud_firestore)
[![Unit Tests](https://github.com/atn832/fake_cloud_firestore/actions/workflows/unit-tests.yaml/badge.svg)](https://github.com/atn832/fake_cloud_firestore/actions/workflows/unit-tests.yaml)
<a href="https://www.buymeacoffee.com/anhtuann" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="30px" width= "108px"></a>

Fakes to write unit tests for Cloud Firestore. Instantiate a
`FakeFirebaseFirestore`, then pass it around your project as if it were a
`FirebaseFirestore`. This Fake acts like Firestore except that will only keep
the data in memory. To help debug, you can use `FakeFirebaseFirestore.dump()` to see what's in the
fake database. This is useful to set up the state of your database, then check that your UI
behaves the way you expect.

This project works well with [firebase_auth_mocks](https://pub.dev/packages/firebase_auth_mocks). If you use them together, you can even test your app with security rules. See [below](#security-rules).

## Usage

### Simple example

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

### In a UI test

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

### Exceptions

#### Based on the state

Most features automatically throw exceptions depending on the state, so you do not need to mock them. For example, calling `DocumentSnapshot.get` on a missing field will throw a `StateError`.

```dart
final firestore = FakeFirebaseFirestore();
final collection = firestore.collection('test');
final doc = collection.doc('test');
await doc.set({
  'nested': {'field': 3}
});

final snapshot = await doc.get();

expect(() => snapshot.get('foo'), throwsA(isA<StateError>()));
expect(() => snapshot.get('nested.foo'), throwsA(isA<StateError>()));
```

#### Mocking exceptions

Furthermore, some methods allow mocking exceptions manually, for example to simulate network errors. You can even set conditions on the parameters using the standard Dart matchers. Here are the methods which support mocking exceptions:

- `DocumentReference.get`, `set`, `update`, `delete`.
- `Query.get`.

```dart
final instance = FakeFirebaseFirestore();
final doc = instance.collection('users').doc(uid);
whenCalling(Invocation.method(#set, null))
    .on(doc)
    .thenThrow(FirebaseException(plugin: 'firestore'));
expect(() => doc.set({'name': 'Bob'}), throwsA(isA<FirebaseException>()));
```

For examples of how to set conditions on when to throw an exception, see [firebase_auth_mocks#throwing-exceptions](https://pub.dev/packages/firebase_auth_mocks#throwing-exceptions).

### Security Rules

You can pass the security rules that you use in production in Firestore to [FakeFirebaseFirestore]. When operating on [DocumentReference] using `get`, `set`, `update`, or `delete`, [FakeFirebaseFirestore] will then check security rules and throw exceptions if access is restricted. In the example below, we restrict `users/{userId}` documents to their respective owners. Before they sign in, they cannot access any document inside the `users` collection. Once they sign in, they have access to only their own `users/[uid]` document.

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:test/test.dart';

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
  test('security rules' {
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
  });
}
```

See <https://github.com/atn832/fake_cloud_firestore/blob/master/test/security_test.dart> for more examples of security rules.

Right now we only support operations on `DocumentReference`. Later we will implement security checks for batch requests, collections and queries. Furthermore, we do not support `timestamps` and `durations` yet. See [Fake Firebase Rules](https://pub.dev/packages/fake_firebase_security_rules) for an exhaustive list of what is and is not supported.

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
  - `FakeFirebaseFirestore` takes authentication state from [firebase_auth_mocks](https://pub.dev/packages/firebase_auth_mocks) into account.
  - `DocumentReference.get`, `set`, `update` and `delete` are protected.

## Compatibility table

| cloud_firestore | fake_cloud_firestore |
|-----------------|----------------------|
| 4.4.0           | 2.4.0                |
| 4.0.0           | 2.0.0                |
| 3.4.0           | 1.3.0                |
| 3.0.0           | 1.2.1                |
| 2.2.0           | 1.1.0                |
| 2.1.0           | 1.0.2                |
| 1.0.0           | 0.8.4                |
| 0.16.0          | 0.6.0                |
| 0.14.0          | 0.5.0                |
| 0.13.1+1        | 0.4.1                |
| 0.13.0+1        | 0.2.5                |
| ^0.12.9+6       | 0.2.0                |

## Features and bugs

Please file feature requests and bugs at the issue tracker.
