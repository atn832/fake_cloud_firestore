# firestore_example

Demonstrates how to use the cloud_firestore_mocks plugin.

The example project comes from
https://github.com/FirebaseExtended/flutterfire/tree/master/packages/cloud_firestore/cloud_firestore/example,
to which I've implemented two unit tests. See
https://github.com/atn832/cloud_firestore_mocks/blob/master/example/test/widget_test.dart.


# Driver Test

The driver test ensures the behavior of cloud_firestore_mocks is the 
same as real Firestore client.

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
Run the following command in "example" directory.

```
~/Documents/cloud_firestore_mocks/example $ flutter drive --target=test_driver/cloud_firestore.dart
...(This may take few minutes)...
flutter: 00:07 +9: (tearDownAll)
flutter: 00:07 +10: All tests passed!
Stopping application instance.
```

## Driver Test with emulator

In `test_driver/cloud_firestore.dart`, update the `host` and `sslEnabled` parameters
as below:

```
      await firestoreWithSettings.settings(
        persistenceEnabled: true,
        host: 'localhost:8080',
        sslEnabled: false,
        cacheSizeBytes: 1048576,
      );
```
