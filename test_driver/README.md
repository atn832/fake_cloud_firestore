# Driver Tests

The `test_driver/cloud_firestore_behaviors` driver test ensures the behavior of 
cloud_firestore_mocks follows the real Firestore client on a device.

It runs the same set of assertions for the following three `Firestore` instances:

- cloud_firestore backed by Cloud Firestore (project ID: flutter-firestore)
- cloud_firestore backed by Firestore emulator
- cloud_firestore_mocks

## Start iOS Simulator

Start iOS simulator. Driver tests require a simulator device to run.

```
$ open /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app
```

## Setup Firestore Emulator

If you don't have `firebase` command, install [Firebase Cli](https://firebase.google.com/docs/cli#install-cli-mac-linux):

```
$ curl -sL https://firebase.tools | bash
...
$ which firebase
/usr/local/bin/firebase
$ firebase setup:emulators:firestore
...
```

This test does not expect firebase.json; the emulator should run without any security rules.

Run Firestore emulator:

```
~/Documents/cloud_firestore_mocks $ firebase emulators:start --only firestore
...
✔  firestore: Emulator started at http://localhost:8080
...
```

`test_driver/cloud_firestore_behaviors` assumes the emulator listen on port
8080 (default) on localhost. This works for iOS simulator running in the same
Mac. (This port setting may need to be changed for Android simulator.)

## Run Driver Test

Open another terminal while keeping the emulator running.
Run the following command in the "example" directory.

```
~/Documents/cloud_firestore_mocks $ flutter drive --target=test_driver/cloud_firestore_behaviors.dart
...
flutter: 00:01 +3: Firestore behavior comparison: Unsaved documens (Cloud Firestore)
flutter: 00:01 +4: Firestore behavior comparison: Unsaved documens (Firestore Emulator)
flutter: 00:01 +5: Firestore behavior comparison: Unsaved documens (cloud_firestore_mocks)
flutter: 00:01 +6: (tearDownAll)
flutter: 00:01 +7: All tests passed!
Stopping application instance.
```

After waiting for few minutes (around 10 minutes for the first invocation),
"All tests passed!" message indicates the driver tests succeeded.
This means that the behaviors of the three `Firestore` instances are the same
for the test cases.

### FieldValue tests

The `field_value_behaviors` is a test for FieldValue implementation.
This test has 2 invocation types. One for cloud_firestore_mocks and the other for
real Firestore and Firestore Emulator backend.

The environment variable `FIRESTORE_IMPLEMENTATION` determines the Cloud Firestore
implementation.

For `cloud_firestore_mocks`:

```
~/Documents/cloud_firestore_mocks $ FIRESTORE_IMPLEMENTATION=cloud_firestore_mocks flutter drive --target=test_driver/field_value_behaviors.dart
...
flutter: 00:00 +13: All tests passed!
Stopping application instance.
```

For `cloud_firestore` (Cloud Firestore and Firestore Emulator):

```
~/Documents/cloud_firestore_mocks $ FIRESTORE_IMPLEMENTATION=cloud_firestore flutter drive --target=test_driver/field_value_behaviors.dart
...
flutter: 00:00 +13: All tests passed!
Stopping application instance.
```

The test invocation for Firestore and Firestore Emulator backend is for reference to ensure
that the three firestore implementations behave in the same manner for the assertions.
Run this only when you change the assertions in field_value_behavior.dart.

#### Background: why does this need 2 separate invocations

A Dart runtime cannot use `FieldValue` implementations of both cloud_firestore and
cloud_firestore_mocks at the same time.
This is because cloud_firestore_mocks overwrites
`FieldValueFactoryPlatform.instance` to use a customized `FieldValueFactory` to swap
FieldValue implementation.
The instance field updates `static final _factory` field of `FieldValue` class.
Because the static final field cannot be updated within one Dart runtime, we need
different `flutter drive` invocations for cloud_firestore and cloud_firestore_mocks.

