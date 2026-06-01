class DartJson {
  final dynamic _value;

  const DartJson(dynamic value) : _value = value;

  Map<String, dynamic> get rawMap {
    if (_value is Map<String, dynamic>) return _value;
    if (_value is Map) {
      try {
        return Map<String, dynamic>.from(_value);
      } catch (_) {
        return const {};
      }
    }
    return const {};
  }

  List<dynamic> get rawList {
    if (_value is List) return List<dynamic>.from(_value);
    return const [];
  }

  bool get isEmpty => rawMap.isEmpty && rawList.isEmpty;
  bool get isNotEmpty => !isEmpty;

  bool has(String key) => rawMap.containsKey(key);
  dynamic rawValue(String key) => rawMap[key];

  String? asString(String key) => _stringFrom(rawMap[key]);
  String stringValue(String key) => asString(key) ?? '';

  int? asInt(String key) => _intFrom(rawMap[key]);
  int intValue(String key) => asInt(key) ?? 0;

  double? asDouble(String key) => _doubleFrom(rawMap[key]);
  double doubleValue(String key) => asDouble(key) ?? 0.0;

  bool? asBool(String key) => _boolFrom(rawMap[key]);
  bool boolValue(String key) => asBool(key) ?? false;

  DateTime? asDate(String key) {
    final value = rawMap[key];
    if (value is DateTime) return value;
    final str = _stringFrom(value);
    if (str == null || str.isEmpty) return null;
    return DateTime.tryParse(str);
  }

  DateTime dateValue(String key) {
    return asDate(key) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<dynamic> asList(String key) => listValue(key);

  List<dynamic> listValue(String key) {
    final value = rawMap[key];
    if (value is List) return List<dynamic>.from(value);
    return const [];
  }

  Map<String, dynamic> asMap(String key) => mapValue(key);

  Map<String, dynamic> mapValue(String key) {
    final value = rawMap[key];
    return DartJson(value).rawMap;
  }

  DartJson jsonValue(String key) => DartJson(rawMap[key]);

  DartJson at(int index) {
    final list = rawList;
    if (index < 0 || index >= list.length) return const DartJson(null);
    return DartJson(list[index]);
  }

  DartJson get lastOrNull {
    final list = rawList;
    if (list.isEmpty) return const DartJson(null);
    return DartJson(list.last);
  }

  String? _stringFrom(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool || value is DateTime) {
      return value.toString();
    }
    return null;
  }

  int? _intFrom(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is bool) return value ? 1 : 0;
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _doubleFrom(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is bool) return value ? 1.0 : 0.0;
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool? _boolFrom(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is double) return value == 1;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return null;
  }

  Map<String, dynamic> get sqlReadyMap {
    return rawMap.map((key, value) => MapEntry(key, _normalizeSqlValue(value)));
  }

  dynamic _normalizeSqlValue(dynamic value) {
    if (value is bool) return value ? 1 : 0;
    return value;
  }
}
