import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_cloud_firestore_test.dart';

void main() {
  test('limit clips results', () async {
    final from = (snapshot, _) => Movie()..title = snapshot['title'];
    final to = (Movie movie, _) => {'title': movie.title};

    final firestore = FakeFirebaseFirestore();

    final moviesCollection = firestore
        .collection('movies')
        .withConverter(fromFirestore: from, toFirestore: to);
    await moviesCollection.add(Movie()..title = 'A long time ago');
    await moviesCollection.add(Movie()..title = 'Robot from the future');
    final rawMoviesCollection = firestore.collection('movies');
    final searchResults = await rawMoviesCollection
        .where('title', isNotEqualTo: 'Galactic')
        .withConverter(fromFirestore: from, toFirestore: to)
        .limit(1)
        .get();
    expect(searchResults.size, equals(1));
    final movieFound = searchResults.docs.first.data();
    expect(movieFound.title, equals('A long time ago'));
  });
}
