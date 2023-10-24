## 2.4.3

- Support mocking Exceptions for `DocumentReference.update`, `set`, `delete`. Thank you [mrunix00](https://github.com/atn832/fake_cloud_firestore/pull/275)! [PR-276](https://github.com/atn832/fake_cloud_firestore/pull/275).

## 2.4.2

Upgraded rx to ^0.3.0 and cloud_firestore_platform_interface to ^6.0.1. [PR-274](https://github.com/atn832/fake_cloud_firestore/pull/274)

## 2.4.1+1

- Support querying with `FieldPath.documentID`. Thank you [agent3bood](https://github.com/atn832/fake_cloud_firestore/pull/264)!

## 2.4.0

Fixed API to support cloud_firestore 4.4.0:

- support Iterable in queries instead of List.
- support FieldPath on `DocumentReference.update`.

Thank you [sydneyagcaoili](https://github.com/atn832/fake_cloud_firestore/pull/266)!

Also fixed deletion so that it reflects on `dump`. Thank you [ga-bri-el](https://github.com/atn832/fake_cloud_firestore/pull/262)!

## 2.3.0+3

Added imports in the README example on security rules.

## 2.3.0+1

Fixed changelog to include a fix in version 2.2.0.

## 2.3.0

- Implemented checking Document access with Security Rules ([PR-260](https://github.com/atn832/fake_cloud_firestore/pull/260)).
- Fixed `DocumentReference.path` to always return a path without a starting '/' ([commit c01eb23](https://github.com/atn832/fake_cloud_firestore/commit/c01eb23bd8836b6c1709164cd8a63b30eca3d6e7)).

## 2.2.0

- Support mocking `Exceptions` for `DocumentReference.set` ([PR-258](https://github.com/atn832/fake_cloud_firestore/pull/258)).
- Support printing out `GeoPoint` in `dump` ([PR-257](https://github.com/atn832/fake_cloud_firestore/pull/257)). Thank you [ga-bri-el](https://github.com/ga-bri-el)!

## 2.1.0

- support `GetOptions.source` when querying data. Thank you [danReynolds](https://github.com/atn832/fake_cloud_firestore/pull/253)!
- fixed Exception code from `cloud_firestore/not-found` to `not-found` to match Firestore. Thank you [Zambrella](https://github.com/atn832/fake_cloud_firestore/pull/252)!
- fixed comparison of `FieldValue.delete()` and `FieldValue.serverTimestamp()` values. Thank you [Zohenn](https://github.com/atn832/fake_cloud_firestore/pull/251)!
- fixed exception when ordering with null values. Thank you [ming-chu](https://github.com/atn832/fake_cloud_firestore/pull/250)!
- implemented `QuerySnapshot.metadata`. Thank you [agent3bood](https://github.com/atn832/fake_cloud_firestore/pull/249)!

## 2.0.1

- implemented `Query.count` for converted queries.

## 2.0.0+2

- migrated to Firestore 4.0.0.
- implemented `Query.count` for collections (converted or not) and non-converted queries.

## 1.3.2

- fixed the handling of maps in `FieldValue.arrayUnion` and `FieldValue.arrayRemove`.
- correctly throws an exception when attempting to save nested lists.
- `DocumentSnapshot.get` correctly throws an exception when a value is not found.

Thank you [Zohenn](https://github.com/Zohenn) for all 3 fixes!

## 1.3.1

- support `Query.limit` for converted queries. Thank you [xni06](https://github.com/xni06)!
- support `DateTime` in `Query.where`. Thank you [Zohenn](https://github.com/Zohenn)!

## 1.3.0

- added `maxAttempts` to `FirebaseFirestore.runTransaction` to match firestore 3.4.0. Thank you [AndrewSheetMetal](https://github.com/AndrewSheetMetal) and [OlegNovosad](https://github.com/OlegNovosad)!

## 1.2.4

- made `Document.update` throw an exception if trying to update a non-existent document.

## 1.2.3

- fixed an exception `Document.update` when replacing a non map value with a map value. Thank you [Sapphirewhale](https://github.com/Sapphirewhale)!
- support `whereNotIn` in `Query.where`. Thank you [KingOfDog](https://github.com/KingOfDog)!
- fixed `orderBy` when used with `startAt`, `endAt`. Thank you [cedvdb](https://github.com/cedvdb)!

## 1.2.2

- support `FieldPath` in `DocumentSnapshot.get()`. Thank you [jpangburn](https://github.com/jpangburn)!
- make `notEqualTo` ignore docs when the field does not exist. Thank you [jpangburn](https://github.com/jpangburn)!
- implemented `endAtDocument`, `endBefore`, `endBeforeDocument` and `startAtDocument` in `Query`. Thank you [Andrew-Bekhiet](https://github.com/Andrew-Bekhiet)!
- make `DocumentReference.snapshots()` emit the first event as soon as the stream is returned. Thank you [Andrew-Bekhiet](https://github.com/Andrew-Bekhiet)!

## 1.2.1

- fixed a regression where DocumentReference stopped firing an event when deleted.
- fixed a null pointer exception when getting a deleted document's snapshot with converter. Thank you [cedvdb](https://github.com/cedvdb)!

## 1.2.0

- migrated to Firestore 3.0.0. Thank you [mboyamike](https://github.com/mboyamike)!
- fixed a null pointer exception when deleting a document using a converter. Thank you [wesleyfuchter](https://github.com/wesleyfuchter)!
- fixed a null pointer exception when using isGreaterThan and the likes on null values. Thank you [fkoch-tgm](https://github.com/fkoch-tgm)!

## 1.1.3

- support Converters for startAt/startAfter/endAt queries.
- fixed a bug where a collection would not fire a snapshot if one of its documents was modified if it was in a sub-collection instead of the root.
- fire an exception when a batch contains more than 500 updates. Thank you [YuKiO-output](https://github.com/YuKiO-output)!

## 1.1.2

- implemented `Query.startAfter`.

## 1.1.1

- fixed a bug where the snapshot wouldn't fire if you got a `Query.snapshot`, then started listening to it after.
- fixed a bug where the snapshot wouldn't fire on an empty collection.

## 1.1.0

- migrated to Firestore 2.2.0.

## 1.0.2

- fixed an exception when calling `snapshots()` on both the raw and converted reference.
- implemented `DocumentReference.set` when using `withConverter`.
- implemented `Query.firestore`.

## 1.0.1

- implemented `withConverter` for `CollectionReference`, `DocumentReference` and `Query`.

## 1.0.0

Breaking change:

- renamed the library from cloud_firestore_mocks to fake_cloud_firestore
- renamed `MockFirestoreInstance` to `FakeFirebaseFirestore`.

### Migration notes

In pubspec.yaml file, replace `cloud_firestore_mocks: ^0.9.0` by `fake_cloud_firestore: ^1.0.0`.

Then in tests, replace:

```dart
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';

final firestore = MockFirestoreInstance();
```

By:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

final firestore = FakeFirebaseFirestore();
```

## 0.9.0

- migrated to Firestore 2.1.0.
- documented a compatibility table.

## 0.8.4

- implemented `DocumentSnapshot.[]` to read a field.

## 0.8.3+1

- fixed compile error.

## 0.8.3

- migrated to sound null safety.
- implemented `Query.startAt`, `Query.endAt` for exact matches. Thank you [maxluchterhand1](https://github.com/maxluchterhand1)!
- implemented `Query.limitToLast`. Thank you [maxluchterhand1](https://github.com/maxluchterhand1)!
- fixed a null pointer exception when query using `Query.where` with composite keys, on documents that didn't have the key. Thank you [ming-chu](https://github.com/ming-chu)!
- support `isNotEqualTo` and `isNull` for `Query.where`. Thank you [alxflam](https://github.com/alxflam)!
- implemented `QuerySnapshot.size`.
- removed dependency to Mockito.

## 0.8.2

- support queries that use composite keys. Thank you [alxflam](https://github.com/alxflam)!

## 0.8.1

- fixed `QueryDocumentSnapshot.data`'s signature change introduced in firestore 1.0.4. Thank you [lyledean1](https://github.com/lyledean1)!

## 0.8.0

- migrated to null safety.
- added documents metadata. Thank you [zariweyo](https://github.com/zariweyo)!

## 0.7.0

- migrated to Firestore 1.0.0. Thank you [Jouby](https://github.com/Jouby)!

## 0.6.0

- migrated to Firestore 0.16.0.

## 0.5.2+1

- restored release notes for 0.4.7.

## 0.5.2

- fix null exception when using `collectionGroup` on documents with no value. Thank you [rhisiart-cufflink](https://github.com/rhisiart-cufflink)!

## 0.5.1

- make `MockDocumentReference.snapshots()` fire on updates. Thank you [gabeschine](https://github.com/gabeschine)!

## 0.5.0+1

- fixed an issue with `runTransaction`. Thank you [sensuikan1973](https://github.com/sensuikan1973)!

## 0.5.0

Support the breaking changes of Firestore 0.14.0. Thank you for the great update [sensuikan1973](https://github.com/sensuikan1973)!

## 0.4.7

- support collection groups (`instance.collectionGroup`). Thank you [sensuikan1973](https://github.com/sensuikan1973)!
- fixed collections so they can contain a subcollection and a document with the same ID. Thank you [dumbbell](https://github.com/dumbbell)!

## 0.4.6+1

- downgraded dependency to collection to satisfy flutter_driver requirements.

## 0.4.6

- support `FieldPath.documentId` in `Query.where` and `orderBy`. Thank you [nukotsuka](https://github.com/nukotsuka)!
- continuously send notifications on queries, even for updates and deletions. Thank you [gki](https://github.com/gki)!
- in `DocumentChange`, populate `oldIndex` and `newIndex`. Thank you [sensuikan1973](https://github.com/sensuikan1973)!
- implemented `QuerySnapshot.documentChanges`. Thank you [feroult](https://github.com/feroult)!

## 0.4.5

- support `FieldValue` and keys containing dots in `CollectionReference.add`. Thank you [nxcco](https://github.com/nxcco)!
- DocumentSnapshots are made with a deep copy of the data. Thank you [amatveyakin](https://github.com/amatveyakin)!
- support `FieldValue` and `DateTime` in nested objects.
- support null values in `Query.orderBy`.
- updated the documentation on integration tests.

## 0.4.4

- support `whereIn` in `CollectionReference.where`.
- `DocumentSnapshot.data` now returns a deep copy.

Thank you [anuragbhd](https://github.com/anuragbhd) for both improvements!

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
