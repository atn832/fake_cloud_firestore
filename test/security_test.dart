import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fake_firebase_security_rules/fake_firebase_security_rules.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

const allowWriteOnlyDescription = '''service cloud.firestore {
  match /databases/{database}/documents {
    match /some_collection/{document} {
      allow write;
    }
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
// Everyone can read /databases/{database} documents, but only admins can write.
// In /databases/{database}/some_collection/{document}, only writers
// can write and only readers can read.
const claimsDefinition = '''
service cloud.firestore {
  match /databases/{database}/documents {
    // For attribute-based access control, check for an admin claim
    match /only_admin_writes/{document} {
      allow write: if request.auth.token.admin == true;
      allow read: true;
    }

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
    expect(() => instance.doc('users/user1').set({'name': 'zeta'}),
        returnsNormally);
  });
  test('write', () {
    final instance =
        FakeFirebaseFirestore(securityRules: allowWriteOnlyDescription);
    expect(() => instance.doc('some_collection/doc1').set({'name': 'zeta'}),
        returnsNormally);
    // Outside of the scope.
    expect(() => instance.doc('outside/doc2').set({'name': 'zeta'}),
        throwsException);
  });
  test('read fails if write only', () {
    final instance =
        FakeFirebaseFirestore(securityRules: allowWriteOnlyDescription);
    expect(() => instance.doc('some_collection/doc1').get(), throwsException);
    expect(() => instance.doc('outside/doc2').get(), throwsException);
  });

  test('getter setter', () async {
    final instance = FakeFirebaseFirestore();
    await instance.doc('users/user1').set({'name': 'zeta'});

    // Can still read at this point.
    // Gotta use `expectLater`. Otherwise, the read may happen after setting the
    // security rules below. See
    // https://pub.dev/documentation/matcher/latest/expect/completes.html
    await expectLater(instance.doc('users/user1').get(), completes);

    // Preventing future reads.
    instance.securityRules =
        FakeFirebaseSecurityRules(allowWriteOnlyDescription);
    expect(() => instance.doc('users/user1').get(), throwsException);
  });

  test('manually simulating authentication', () async {
    final auth = BehaviorSubject<Map<String, dynamic>?>();
    final instance = FakeFirebaseFirestore(
        securityRules: authUidDescription, authObject: auth);
    // Unauthenticated. Make sure we wait until this is finished to
    // authenticate.
    await expectLater(
        () => instance.doc('users/abc').set({'name': 'zeta'}), throwsException);

    // Authenticated.
    auth.add({'uid': 'abc'});

    expect(
        () => instance.doc('users/abc').set({'name': 'zeta'}), returnsNormally);
    // Wrong uid.
    expect(
        () => instance.doc('users/def').set({'name': 'zeta'}), throwsException);
  });
  group('Firebase Auth Mocks', () {
    test('users can only read their own document', () async {
      final auth = MockFirebaseAuth();
      final firestore = FakeFirebaseFirestore(
          // Pass security rules to restrict `/users/{user}` documents.
          securityRules: authUidDescription,
          // Make MockFirebaseAuth inform FakeFirebaseFirestore of sign-in
          // changes.
          authObject: auth.authForFakeFirestore);
      // The user signs-in. FakeFirebaseFirestore knows about it thanks to
      // `authObject`.
      await auth.signInWithCustomToken('some token');
      final uid = auth.currentUser!.uid;
      // Now the user can access their user-specific document.
      expect(() => firestore.doc('users/$uid').set({'name': 'abc'}),
          returnsNormally);
      // But not anyone else's.
      expect(() => firestore.doc('users/abcdef').set({'name': 'abc'}),
          throwsException);
      // Nor can they delete
      expect(() => firestore.doc('users/abcdef').delete(), throwsException);
    });
    test('recursive custom claims', () async {
      final a = MockFirebaseAuth(
          mockUser:
              MockUser(displayName: 'sam smith', customClaim: {'admin': true}));
      final f = FakeFirebaseFirestore(
          securityRules: claimsDefinition, authObject: a.authForFakeFirestore);
      await a.signInWithCustomToken('some token');
      // Can write in admin only collection.
      expect(() => f.doc('only_admin_writes/doc1').set({'name': 'abc'}),
          returnsNormally);
      // Cannot access random collections.
      expect(() => f.doc('other_collection/doc5').set({'name': 'abc'}),
          throwsException);
      // Should not be able to write in some_collection, since admin is not a
      // writer.
      expect(() => f.doc('some_collection/painting').get(), throwsException);
    });
    group('leaf custom custom claims', () {
      test('no role', () async {
        // No custom claims.
        final a = MockFirebaseAuth(mockUser: MockUser(displayName: 'Jim'));
        final f = FakeFirebaseFirestore(
            securityRules: claimsDefinition,
            authObject: a.authForFakeFirestore);
        await a.signInWithCustomToken('some token');
        // Can read only_admin_writes, since it is open to reading.
        expect(() => f.doc('only_admin_writes/doc1').get(), returnsNormally);
        // Cannot write the root. Only admins can.
        expect(() => f.doc('only_admin_writes/doc1').set({'name': 'abc'}),
            throwsException);
        // Jim can neither read...
        expect(() => f.doc('some_collection/painting').get(), throwsException);
        // Nor write.
        expect(() => f.doc('some_collection/painting').set({'name': 'tree'}),
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
        expect(() => f.doc('only_admin_writes/doc1').set({'name': 'abc'}),
            throwsException);
        // Jack can read.
        expect(() => f.doc('some_collection/painting').get(), returnsNormally);
        // Jack not write.
        expect(() => f.doc('some_collection/painting').set({'name': 'tree'}),
            throwsException);
      });
    });
  });
}
