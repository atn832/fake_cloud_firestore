import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  String users = "users";
  MockFirestoreInstance firestore = MockFirestoreInstance();

  Map<String, dynamic> userDocumentMock(String userId) {
    Map<String, dynamic> data = {
      "id": userId,
      "updatedAt": DateTime.now(),
      "createdAt": DateTime.now(),
    };
    return data;
  }

  Future<List<Map<String, dynamic>>> createUsers({int times}) async {
    List<Map<String, dynamic>> userDataList = [];
    for (int i = 1; i <= times; ++i) {
      String userId = i.toString();
      userDataList.add(userDocumentMock(userId));
    }
    return userDataList;
  }

  setUp(() async {});
  tearDown(() async {});

  group("batch", () {
    test("succees when create 500 documents at once.", () async {
      List<Map<String, dynamic>> userDataList = await createUsers(times: 500);
      int userDataListLength = userDataList.length;
      for (int i = 0; i < userDataListLength; i = i + 500) {
        int first = i;
        int last = i + 500;
        if (last >= userDataListLength) {
          last = userDataListLength;
        }
        var selectUserDataList = userDataList.getRange(first, last);
        var batch = firestore.batch();
        await Future.forEach(selectUserDataList, (data) async {
          var document = firestore.collection(users).doc("${data["id"]}");
          batch.set(document, data);
        });
        await batch.commit();
      }
      QuerySnapshot result = await firestore.collection(users).get();
      expect(result.docs.length, 1000);
    });
    test("fail when create 501 documents at once.", () async {
      List<Map<String, dynamic>> userDataList = await createUsers(times: 501);
      int userDataListLength = userDataList.length;

      for (int i = 0; i < userDataListLength; i = i + 501) {
        int first = i;
        int last = i + 501;
        if (last >= userDataListLength) {
          last = userDataListLength;
        }
        var selectUserDataList = userDataList.getRange(first, last);
        var batch = firestore.batch();
        await Future.forEach(selectUserDataList, (data) async {
          var document = firestore.collection(users).doc("${data["id"]}");
          batch.set(document, data);
        });
  QuerySnapshot result = await firestore.collection(users).get();
        expect(result.docs.length, 0);
      }
    });
  });
}
