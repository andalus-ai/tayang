import 'dart:math';

final _random = Random();

/// Collision-resistant enough for local, single-user ids.
String newId([String prefix = '']) {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final salt = _random.nextInt(1 << 24).toRadixString(36);
  return '$prefix$time$salt';
}
