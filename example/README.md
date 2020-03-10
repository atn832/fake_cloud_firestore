# firestore_example

Demonstrates how to use the cloud_firestore_mocks plugin.

The example project comes from
https://github.com/FirebaseExtended/flutterfire/tree/master/packages/cloud_firestore/cloud_firestore/example,
to which I've implemented two unit tests. See
https://github.com/atn832/cloud_firestore_mocks/blob/master/example/test/widget_test.dart.


# Driver Test

The `test_driver/cloud_firestore_behaviors` driver test ensures the behavior of 
cloud_firestore_mocks follows the real Firestore client for both Cloud Firestore
backend and emulator backend.

## Setup Firebase Emulator

Install [Firebase Cli](https://firebase.google.com/docs/cli#install-cli-mac-linux):

```
curl -sL https://firebase.tools | bash
...
~/Documents/cloud_firestore_mocks $ which firebase
/usr/local/bin/firebase
```

```
~/Documents/cloud_firestore_mocks $ firebase emulators:start --only firestore
...
i  firestore: For testing set FIRESTORE_EMULATOR_HOST=localhost:8080
...
```

## Run Driver Test

Open another terminal while keeping the emulator running.
Run the following command in the "example" directory.

```
~/Documents/cloud_firestore_mocks/example $ flutter drive --target=test_driver/cloud_firestore_behaviors.dart
...
flutter: 00:01 +3: Firestore behavior comparison: Unsaved documens (Cloud Firestore)
flutter: 00:01 +4: Firestore behavior comparison: Unsaved documens (Firestore Emulator)
flutter: 00:01 +5: Firestore behavior comparison: Unsaved documens (cloud_firestore_mocks)
flutter: 00:01 +6: (tearDownAll)
flutter: 00:01 +7: All tests passed!
Stopping application instance.
```
