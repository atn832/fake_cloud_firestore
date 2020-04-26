## 0.4.3+1

- updated docs.

## 0.4.3

- support `Query.startAfterDocument`. Thank you [Hadii1](https://github.com/Hadii1)!
- support `arrayContains` in `CollectionReference.where`. Thank you [qwales1](https://github.com/qwales1)!
- support `arrayContainsAny` in `CollectionReference.where`. Thank you [anuragbhd](https://github.com/anuragbhd)!
- support document paths with slashes. Thank you [suztomo](https://github.com/suztomo)!
- support Document and Collection's `parent`, `path`, `firebase`, and `equals` methods. Thank you [suztomo](https://github.com/suztomo)!

## 0.4.2

New features:

- support `Firestore.runTransaction`.
- support `FieldValue.increment`, `arrayUnion`, and `arrayRemove`.

Adhering to Firebase specs:

- `Firestore.document` and `collection` check the number of segments.
- `Query` executes only when calling `getDocuments`.
- Updating a document doesn't affect previous `Snapshots`.
- saves a deep copy when when saving data to a document.
- checks that data types are valid upon saving data.

All credits go to [suztomo](https://github.com/suztomo). Thank you!

## 0.4.1

- `CollectionReference.getDocuments` returns only documents that have been saved by `CollectionReference.add` or `DocumentReference.setData` or `DocumentReference.updateData`.
- make `CollectionReference.add` generate a random `documentId`.
- support batch operations `updateData` and `delete`.
- implemented `DocumentReference.path`.
- implemented `DocumentSnapshot.reference`.

Thank you [suztomo](https://github.com/suztomo) for contributing these improvements!

## 0.4.0+1

- fixed some lint error.

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
