
# Driver Test: test_driver/cloud_firestore_behaviors

The `test_driver/cloud_firestore_behaviors` driver test ensures the behavior of 
cloud_firestore_mocks follows the real Firestore client.

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
