## 0.4.0

- support `CollectionReference.document()`. Thanks [suztomo](https://github.com/suztomo)!
- support nested documents. Thanks [suztomo](https://github.com/suztomo)!
- support `FieldValue.serverTimestamp()`. Thanks [suztomo](https://github.com/suztomo)!
- breaking change: remove requirement to call `setupFieldValueFactory()`. They are now initialized automatically when `MockFirestoreInstance` is instantiated.

## 0.3.1

- support `FieldValue.delete()` again.

## 0.3.0

- fixed breakage due to `FieldValue.type` and `FieldValue.value` being removed from the public API at [cloud_firestore 0.10.0](https://pub.dev/packages/cloud_firestore#0100).
- implemented chainable `Query.where`. Thank you [qwales1](https://github.com/qwales1)!
- dropped support for `FieldValue.delete()`.

## 0.2.7

- implemented `DocumentSnapshot.exists`. Thank you [qwales1](https://github.com/qwales1)!

## 0.2.6

- implemented `MockDocumentReference.snapshots()`. Thank you [dfdgsdfg](https://github.com/dfdgsdfg) and [terry960302](https://github.com/terry960302)!

## 0.2.5

- upgraded cloud_firestore to ^0.13.0+1.

## 0.2.4

- cleaned up the public documentation to expose only `MockFirestoreInstance`.

## 0.2.3

- fixed code health related issues.

## 0.2.2

- added support for `isGreaterThanOrEqualTo`, `isLessThan`, `isLessThanOrEqualTo` in `CollectionReference.where`.
- implemented mock `DocumentReference.delete`.

## 0.2.1

- Fixed snapshots not firing several times.
- Implemented example unit tests based on Firestore's own example project.

## 0.2.0

- Initial version.
