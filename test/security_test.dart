import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

const allowWriteOnlyDescription = '''service cloud.firestore {
  match /databases/{database}/documents {
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

// https://firebase.google.com/docs/rules/rules-and-auth#define_custom_user_information
// Everyone can read /databases/{database}/documents, but only admins can write.
// In /databases/{database}/documents/some_collection/{document}, only writers
// can write and only readers can read.
const claimsDefinition = '''
service cloud.firestore {
  match /databases/{database}/documents {
    // For attribute-based access control, check for an admin claim
    allow write: if request.auth.token.admin == true;
    allow read: true;

    // Alternatively, for role-based access, assign specific roles to users
    match /some_collection/{document} {
      allow read: if request.auth.token.reader == true;
      allow write: if request.auth.token.writer == true;
    }
  }
}
''';

void main() {
  test('by default, allows everything just like before', () {
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
    // Outside of the scope.
    expect(() => instance.doc('/outside/db1/documents').set({'name': 'zeta'}),
        throwsException);
  });
  test('read', () {
    final instance = FakeFirebaseFirestore(securityRules: allowAllDescription);
    expect(
        () => instance.doc('/databases/db1/documents').get(), throwsException);
    expect(() => instance.doc('/outside/db1/documents').get(), throwsException);
  });
  test('manually simulating authentication', () async {
    final auth = BehaviorSubject<Map<String, dynamic>?>();
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
  group('Firebase Auth Mocks', () {
    test('adds one to input values', () async {
      final a = MockFirebaseAuth(mockUser: MockUser(displayName: 'sam smith'));
      final f = FakeFirebaseFirestore(
          securityRules: authUidDescription,
          authObject: a.authForFakeFirestore);
      await a.signInWithCustomToken('some token');
      final uid = a.currentUser!.uid;
      expect(
          () =>
              f.doc('/databases/db1/documents/users/$uid').set({'name': 'abc'}),
          returnsNormally);
      expect(
          () => f
              .doc('/databases/db1/documents/users/abcdef')
              .set({'name': 'abc'}),
          throwsException);
    });
    test('recursive custom claims', () async {
      final a = MockFirebaseAuth(
          mockUser:
              MockUser(displayName: 'sam smith', customClaim: {'admin': true}));
      final f = FakeFirebaseFirestore(
          securityRules: claimsDefinition, authObject: a.authForFakeFirestore);
      await a.signInWithCustomToken('some token');
      // Can write the root.
      expect(() => f.doc('/databases/db1/documents').set({'name': 'abc'}),
          returnsNormally);
      // Cannot access outside the root.
      expect(() => f.doc('/databases/db1/other-documents').set({'name': 'abc'}),
          returnsNormally);
      // TODO: fix?
      // Should it be able to recursively access children? Probably not.
      expect(
          () =>
              f.doc('/databases/db1/documents/some_collection/painting').get(),
          returnsNormally);
    });
    group('leaf custom custom claims', () {
      test('no role', () async {
        // No custom claims.
        final a = MockFirebaseAuth(mockUser: MockUser(displayName: 'Jim'));
        final f = FakeFirebaseFirestore(
            securityRules: claimsDefinition,
            authObject: a.authForFakeFirestore);
        await a.signInWithCustomToken('some token');
        // Can read the root.
        expect(() => f.doc('/databases/db1/documents').get(), returnsNormally);
        // Cannot write the root. Only admins can.
        expect(() => f.doc('/databases/db1/documents').set({'name': 'abc'}),
            throwsException);
        // Jim can neither read...
        expect(
            () => f
                .doc('/databases/db1/documents/some_collection/painting')
                .get(),
            throwsException);
        // Nor write.
        expect(
            () => f
                .doc('/databases/db1/documents/some_collection/painting')
                .set({'name': 'tree'}),
            throwsException);
      });
      test('reader', () async {
        final a = MockFirebaseAuth(
            mockUser:
                MockUser(displayName: 'Jack', customClaim: {'reader': true}));
        final f = FakeFirebaseFirestore(
            securityRules: claimsDefinition,
            authObject: a.authForFakeFirestore);
        await a.signInWithCustomToken('some token');
        // Cannot write the root. Only admins can.
        expect(() => f.doc('/databases/db1/documents').set({'name': 'abc'}),
            throwsException);
        // Jack can read.
        expect(
            () => f
                .doc('/databases/db1/documents/some_collection/painting')
                .get(),
            returnsNormally);
        // Jack not write.
        expect(
            () => f
                .doc('/databases/db1/documents/some_collection/painting')
                .set({'name': 'tree'}),
            throwsException);
      });
    });
  });
}
