import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

const allowAllDescription = '''service cloud.firestore {
  match /databases/{database}/documents {
    // For attribute-based access control, check for an admin claim
    allow write;
  }
}''';

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

void main() {
  test('no security allows everything', () {
    final instance = FakeFirebaseFirestore();
    expect(() => instance.doc('/databases/db1/documents').set({'name': 'zeta'}),
        returnsNormally);
    expect(() => instance.doc('/outside/db1/documents').set({'name': 'zeta'}),
        returnsNormally);
  });
  test('write', () {
    final instance = FakeFirebaseFirestore(securityRules: allowAllDescription);
    expect(() => instance.doc('/databases/db1/documents').set({'name': 'zeta'}),
        returnsNormally);
    expect(() => instance.doc('/outside/db1/documents').set({'name': 'zeta'}),
        throwsException);
  });
  test('read', () {
    final instance = FakeFirebaseFirestore(securityRules: allowAllDescription);
    expect(
        () => instance.doc('/databases/db1/documents').get(), throwsException);
    expect(() => instance.doc('/outside/db1/documents').get(), throwsException);
  });
  test('authentication', () async {
    final auth = BehaviorSubject<Map<String, dynamic>?>.seeded(null);
    final instance = FakeFirebaseFirestore(
        securityRules: authUidDescription, authObject: auth);
    // Unauthenticated. Make sure we wait until this is finished to
    // authenticate.
    await expectLater(
        () => instance
            .doc('/databases/db1/documents/users/abc')
            .set({'name': 'zeta'}),
        throwsException);

    // Authenticated.
    auth.add({'uid': 'abc'});
    expect(
        () => instance
            .doc('/databases/db1/documents/users/abc')
            .set({'name': 'zeta'}),
        returnsNormally);
    // Wrong uid.
    expect(
        () => instance
            .doc('/databases/db1/documents/users/def')
            .set({'name': 'zeta'}),
        throwsException);
  });
}
