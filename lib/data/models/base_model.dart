import 'dart:convert';

abstract class BaseModel {
  int? get id;

  Map<String, Object?> toMap();

  String get uniqueKey;

  Object? get uniqueKeyValue;
}

extension BaseModelJsonExtension on BaseModel {
  String get toJsonString => jsonEncode(toMap());

  String get toJsonPretty => const JsonEncoder.withIndent('  ').convert(toMap());
}

extension BaseModelListJsonExtension<T extends BaseModel> on List<T> {
  String get toJsonString => jsonEncode(map((item) => item.toMap()).toList());

  String get toJsonPretty =>
      const JsonEncoder.withIndent('  ').convert(map((item) => item.toMap()).toList());
}
