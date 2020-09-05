import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:test/test.dart';

import 'document_snapshot_matcher.dart';

class QuerySnapshotMatcher implements Matcher {
  final List<DocumentSnapshotMatcher> _documentSnapshotMatchers;

  QuerySnapshotMatcher(this._documentSnapshotMatchers);

  @override
  Description describe(Description description) {
    return StringDescription("Matches a query snapshot's DocumentSnapshots.");
  }

  @override
  Description describeMismatch(
      item, Description mismatchDescription, Map matchState, bool verbose) {
    mismatchDescription.add('Snapshot does not match expected data.');

    // TODO: this will crash if there are fewer matchers than documents.

    final snapshot = item as QuerySnapshot;
    for (var i = 0; i < snapshot.docs.length; i++) {
      final matcher = _documentSnapshotMatchers[i];
      final item = snapshot.docs[i];
      if (!matcher.matches(item, matchState)) {
        matcher.describeMismatch(
            item, mismatchDescription, matchState, verbose);
      }
    }
    return mismatchDescription;
  }

  @override
  bool matches(item, Map matchState) {
    final snapshot = item as QuerySnapshot;
    if (snapshot.docs.length != _documentSnapshotMatchers.length) {
      return false;
    }
    for (var i = 0; i < snapshot.docs.length; i++) {
      final matcher = _documentSnapshotMatchers[i];
      if (!matcher.matches(snapshot.docs[i], matchState)) {
        return false;
      }
    }
    return true;
  }
}
