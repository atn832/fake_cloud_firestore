import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';

abstract class FakeServerTimeProvider {
  Timestamp get now;
}

class FixedServerTimeProvider implements FakeServerTimeProvider {
  final Timestamp _now;

  FixedServerTimeProvider(this._now);

  @override
  Timestamp get now => _now;
}
