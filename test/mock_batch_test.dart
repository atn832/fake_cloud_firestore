import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

void main() async {
  final usersPath = 'users';

  Map<String, dynamic> createUserData(String userId) {
    return {
      'id': userId,
    };
  }

  List<Map<String, dynamic>> createUsers({required int times}) {
    final userDataList = <Map<String, dynamic>>[];
    for (var i = 0; i < times; i++) {
      final userId = i.toString();
      userDataList.add(createUserData(userId));
    }
    return userDataList;
  }

  group('batch', () {
    test('succees when create 500 documents at once.', () async {
      final firestore = FakeFirebaseFirestore();
      final userDataList = createUsers(times: 500);
      final batch = firestore.batch();
      for (final userData in userDataList) {
        final documentRef = firestore.collection(usersPath).doc(userData['id']);
        batch.set(documentRef, userData);
      }
      await batch.commit();
      final result = await firestore.collection(usersPath).get();
      expect(result.docs.length, 500);
    });

    test('fail when create 501 documents at once.', () async {
      final firestore = FakeFirebaseFirestore();
      final userDataList = createUsers(times: 501);
      final batch = firestore.batch();
      for (final userData in userDataList) {
        final documentRef = firestore.collection(usersPath).doc(userData['id']);
        batch.set(documentRef, userData);
      }
      expect(() => batch.commit(), throwsException);
    });

    test('exception during batch commit.', () async {
      final firestore = FakeFirebaseFirestore();
      final userData = createUsers(times: 1)[0];

      final documentRef = firestore.collection(usersPath).doc(userData['id']);
      whenCalling(Invocation.method(#set, null))
          .on(documentRef)
          .thenThrow(FirebaseException(plugin: 'firestore'));

      final batch = firestore.batch();
      batch.set(documentRef, userData);

      expect(
          () async => await batch.commit(), throwsA(isA<FirebaseException>()));
    });
  });
}
