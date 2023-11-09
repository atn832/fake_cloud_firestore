import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fake_cloud_firestore/src/util.dart';
import 'package:test/test.dart';

void main() {
  late FakeFirebaseFirestore instance;

  setUp(() async {
    instance = FakeFirebaseFirestore();
    await instance.collection('users').add({
      'name': 'Bob',
      'friends': [
        'friends/marie_doc'
      ]
    });
    await instance.collection('users').add({
      'name': 'Marie',
      'friends': [
        'friends/bob_doc'
      ]
    });
  });

  test('Should allow concurrent cache modifications', () {
    instance
        .collection('users')
        .snapshots().listen((QuerySnapshot<Map<String, dynamic>> snapshot){
          for (final docChange in snapshot.docChanges){
            instance
                .collection('users')
                .doc(docChange.doc.data())
                .snapshots().listen((QuerySnapshot<Map<String, dynamic>> snapshot){

          }

          print("snapshot ${snapshot.docChanges}");
    });

  });

}
