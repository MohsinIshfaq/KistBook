import 'dart:math';

class IdGenerator {
  static final Random _random = Random();

  static String localUuid() {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final randomPart = List.generate(
      16,
      (_) => _random.nextInt(16).toRadixString(16),
    ).join();
    return '$timestamp-$randomPart';
  }
}
