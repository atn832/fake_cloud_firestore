import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fake_firebase_security_rules/fake_firebase_security_rules.dart';
import 'package:test/test.dart';

const allowAllDescription = '''service cloud.firestore {
  match /databases/{database}/documents {
    // For attribute-based access control, check for an admin claim
    allow write;
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
    final rules = FakeFirebaseSecurityRules(allowAllDescription);
    final instance = FakeFirebaseFirestore(securityRules: rules);
    expect(() => instance.doc('/databases/db1/documents').set({'name': 'zeta'}),
        returnsNormally);
    expect(() => instance.doc('/outside/db1/documents').set({'name': 'zeta'}),
        throwsException);
  });
}
