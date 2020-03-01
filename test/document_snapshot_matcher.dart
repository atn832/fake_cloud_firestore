import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:test/test.dart';

class DocumentSnapshotMatcher implements Matcher {
  String _documentId;
  Map<String, dynamic> _data;

  DocumentSnapshotMatcher(this._documentId, this._data);

  @override
  Description describe(Description description) {
    return StringDescription("Matches a snapshot's documentId and data");
  }

  @override
  Description describeMismatch(
      item, Description mismatchDescription, Map matchState, bool verbose) {
    final snapshot = item as DocumentSnapshot;
    // TODO: generate more meaningful descriptions.
    if (!equals(snapshot.documentID).matches(_documentId, matchState)) {
      equals(snapshot.documentID).describeMismatch(
          _documentId, mismatchDescription, matchState, verbose);
    }
    if (!equals(snapshot.data).matches(_data, matchState)) {
      equals(snapshot.data)
          .describeMismatch(_data, mismatchDescription, matchState, verbose);
    }
    return mismatchDescription;
  }

  @override
  bool matches(item, Map matchState) {
    final snapshot = item as DocumentSnapshot;
    return equals(snapshot.documentID).matches(_documentId, matchState) &&
        equals(snapshot.data).matches(_data, matchState);
  }
}
