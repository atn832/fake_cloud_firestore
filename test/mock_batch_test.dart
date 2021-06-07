import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  final usersPath = "users";
  final firestore = MockFirestoreInstance();
  Map<String, dynamic> userDocumentMock(String userId) {
    return {
      "id": userId,
      "updatedAt": DateTime.now(),
      "createdAt": DateTime.now(),
    };
  }

  Future<List<Map<String, dynamic>>> createUsers({required int times}) async {
    List<Map<String, dynamic>> userDataList = [];
    for (int i = 0; i < times; i++) {
      final userId = i.toString();
      userDataList.add(userDocumentMock(userId));
    }
    return userDataList;
  }

  group("batch", () {
    test("succees when create 500 documents at once.", () async {
      List<Map<String, dynamic>> userDataList = await createUsers(times: 500);
      final userDataListLength = userDataList.length;
      for (int i = 0; i < userDataListLength; i = i + 500) {
        final first = i;
        final last = min(i + 500, userDataListLength);

        var selectUserDataList = userDataList.getRange(first, last);
        var batch = firestore.batch();
        for (final userData in selectUserDataList) {
          final documentRef =
              firestore.collection(usersPath).doc(userData["id"]);
          batch.set(documentRef, userData);
        }
        await batch.commit();
      }
      QuerySnapshot result = await firestore.collection(usersPath).get();
      expect(result.docs.length, 500);
    });

    test("fail when create 501 documents at once.", () async {
      List<Map<String, dynamic>> userDataList = await createUsers(times: 501);
      var batch = firestore.batch();
      for (final userData in userDataList) {
        final documentRef = firestore.collection(usersPath).doc(userData["id"]);
        batch.set(documentRef, userData);
      }
      expect(() => batch.commit(), throwsException);
    });
  });
}
