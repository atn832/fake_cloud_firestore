import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:test/test.dart';

class DocumentSnapshotMatcher implements Matcher {
  // This may be null if no need to match ID
  final String? _documentId;
  final Map<String, dynamic>? _data;

  DocumentSnapshotMatcher(this._documentId, this._data);

  /// Matcher for data only, without matching documentId.
  static DocumentSnapshotMatcher onData(Map<String, dynamic> data) {
    return DocumentSnapshotMatcher(null, data);
  }

  @override
  Description describe(Description description) {
    return StringDescription("Matches a snapshot's documentId and data");
  }

  @override
  Description describeMismatch(
      item, Description mismatchDescription, Map matchState, bool verbose) {
    final snapshot = item as DocumentSnapshot;
    // TODO: generate more meaningful descriptions.
    if (_documentId != null &&
        !equals(snapshot.id).matches(_documentId, matchState)) {
      equals(snapshot.id).describeMismatch(
          _documentId, mismatchDescription, matchState, verbose);
    }
    if (!equals(snapshot.data()).matches(_data, matchState)) {
      equals(snapshot.data())
          .describeMismatch(_data, mismatchDescription, matchState, verbose);
    }
    return mismatchDescription;
  }

  @override
  bool matches(item, Map matchState) {
    final snapshot = item as DocumentSnapshot;
    if (_documentId == null) {
      return equals(snapshot.data()).matches(_data, matchState);
    }
    return equals(snapshot.id).matches(_documentId, matchState) &&
        equals(snapshot.data()).matches(_data, matchState);
  }
}
