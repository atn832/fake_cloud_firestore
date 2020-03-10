# firestore_example

Demonstrates how to use the cloud_firestore_mocks plugin.

The example project comes from
https://github.com/FirebaseExtended/flutterfire/tree/master/packages/cloud_firestore/cloud_firestore/example,
to which I've implemented two unit tests. See
https://github.com/atn832/cloud_firestore_mocks/blob/master/example/test/widget_test.dart.


# Driver Test

The driver test ensures the behavior of cloud_firestore_mocks is the 
same as real Firestore client.

```
example $ flutter drive --target=test_driver/cloud_firestore.dart
```
